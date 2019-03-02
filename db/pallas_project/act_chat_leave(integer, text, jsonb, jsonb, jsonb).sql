-- drop function pallas_project.act_chat_leave(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_chat_leave(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_chat_code text := json.get_string(in_params, 'chat_code');
  v_chat_id integer := data.get_object_id(v_chat_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_actor_code text := data.get_object_code(v_actor_id);

  v_person_id integer;
  v_person_code text;

  v_message_id integer;
  v_message_code text;
  v_message_class_id integer := data.get_class_id('message');

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_subtitle_attribute_id integer := data.get_attribute_id('subtitle');
  v_message_text_attribute_id integer := data.get_attribute_id('message_text');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_system_message_sender_attribute_id integer := data.get_attribute_id('system_message_sender');
  v_system_message_time_attribute_id integer := data.get_attribute_id('system_message_time');

  v_all_chats_id integer := data.get_object_id('all_chats');
  v_chats_id integer := data.get_object_id(v_actor_code || '_chats');
  v_master_chats_id integer := data.get_object_id(v_actor_code || '_master_chats');

  v_master_group_id integer := data.get_object_id('master');

  v_content text[];
  v_new_content text[];
  v_message_sent boolean := false;

  v_chat_bot_id integer := data.get_object_id('chat_bot');

  v_is_master boolean := pp_utils.is_in_group(v_actor_id, 'master');
  v_actor_title text := json.get_string(data.get_attribute_value(v_actor_id, v_title_attribute_id));
  v_title text := to_char(clock_timestamp(),'DD.MM hh24:mi:ss');
  v_chat_title text := json.get_string_opt(data.get_attribute_value(v_chat_id, v_title_attribute_id), null);
  v_chat_is_renamed boolean := json.get_boolean_opt(data.get_attribute_value_for_share(v_chat_id, 'system_chat_is_renamed'), false);
  v_chat_parent_list text := json.get_string_opt(data.get_attribute_value(v_chat_id, 'system_chat_parent_list'), '~');

  v_name jsonb;
  v_persons text:= '';
  v_changes jsonb[];
begin
  assert in_request_id is not null;

  -- проверяем, что выходить можно
  assert v_is_master or json.get_boolean_opt(data.get_attribute_value(v_actor_id, 'system_chat_can_leave'), true);

  -- Удаляемся из группы чата
  perform data.process_diffs_and_notify(data.change_object_groups(v_actor_id, array[]::integer[], array[v_chat_id], v_actor_id));

  -- Удаляем чат из своего списка чатов
  if v_chat_parent_list = 'master_chats' then
    perform pp_utils.list_remove_and_notify(v_master_chats_id, v_chat_code, null);
  else
    perform pp_utils.list_remove_and_notify(v_chats_id, v_chat_code, null);
  end if;

  -- Мастера в чате не видно, поэтому светить его выход не надо
  if not v_is_master or v_chat_parent_list = 'master_chats' then
    -- Меняем список участников чата в заголовке
    for v_name in (select x.name from jsonb_to_recordset(pallas_project.get_chat_persons(v_chat_id, (v_chat_parent_list <> 'master_chats'))) as x(code text, name jsonb) limit 3) loop 
      v_persons := v_persons || ','|| json.get_string(v_name);
    end loop;
    v_persons := trim(v_persons, ',');

    v_changes := array[]::jsonb[];
    if not v_chat_is_renamed then
      v_changes := array_append(v_changes, data.attribute_change2jsonb(v_title_attribute_id, to_jsonb(v_persons)));
    else
      v_changes := array_append(v_changes, data.attribute_change2jsonb(v_subtitle_attribute_id, to_jsonb(v_persons)));
    end if;
    perform data.change_object_and_notify(v_chat_id, 
                                          to_jsonb(v_changes),
                                          v_actor_id);

    -- Меняем привязанный к чату список для участников
    perform pallas_project.change_chat_person_list_on_person(
      v_chat_id,
      case when not v_chat_is_renamed then v_persons else null end,
      (v_chat_parent_list = 'master_chats'));

    -- Создаём новое сообщение о том, что персонаж вышел из чата
    insert into data.objects(class_id) values (v_message_class_id) returning id, code into v_message_id, v_message_code;

    insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
    (v_message_id, v_title_attribute_id, to_jsonb(v_title), null),
    (v_message_id, v_message_text_attribute_id, to_jsonb(v_actor_title || ' вышел из чата'), null),
    (v_message_id, v_is_visible_attribute_id, jsonb 'true', v_chat_id),
    (v_message_id, v_system_message_sender_attribute_id, to_jsonb(v_chat_bot_id), null),
    (v_message_id, v_system_message_time_attribute_id, to_jsonb(to_char(clock_timestamp(),'DD.MM.YYYY hh24:mi:ss') ), null);

    -- Добавляем сообщение в чат
    perform pp_utils.list_prepend_and_notify(v_chat_id, v_message_code, null, v_chat_id);

    -- Перекладываем этот чат в начало в мастерском списке чатов
    if v_chat_parent_list = 'chats' then
      perform pp_utils.list_replace_to_head_and_notify(v_all_chats_id, v_chat_code, null);
    end if;

    -- Отправляем нотификацию о новом сообщении всем неподписанным на этот чат
    -- и перекладываем у всех участников этот чат вверх списка
    for v_person_id in 
      (select oo.object_id from data.object_objects oo 
       where oo.parent_object_id = v_chat_id
         and oo.parent_object_id <> oo.object_id)
    loop
      v_person_code := data.get_object_code(v_person_id);
      if v_chat_parent_list = 'master_chats' then
        perform pp_utils.list_replace_to_head_and_notify(data.get_object_id(v_person_code || '_master_chats'), v_chat_code, null);
      elsif v_chat_parent_list = 'chats' then
        perform pp_utils.list_replace_to_head_and_notify(data.get_object_id(v_person_code || '_chats'), v_chat_code, v_person_id);
      end if;
      if v_person_id <> v_actor_id 
        and not json.get_boolean_opt(data.get_attribute_value(v_chat_id, 'chat_is_mute', v_person_id), false) then
        perform pp_utils.add_notification_if_not_subscribed(v_person_id, v_actor_title || ' вышел из чата ' || v_chat_title, v_chat_id);
      end if;
    end loop;
  end if;

  -- Переходим к списку чатов
  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_actor_code || '_chats');
end;
$$
language plpgsql;
