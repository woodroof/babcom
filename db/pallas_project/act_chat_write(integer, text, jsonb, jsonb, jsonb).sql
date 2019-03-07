-- drop function pallas_project.act_chat_write(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_chat_write(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_chat_code text := json.get_string(in_params, 'chat_code');
  v_chat_id integer := data.get_object_id(v_chat_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_person_id integer;
  v_person_code text;

  v_message_text text := json.get_string(in_user_params, 'message_text');

  v_message_id integer;
  v_message_code text;
  v_message_class_id integer := data.get_class_id('message');

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_message_text_attribute_id integer := data.get_attribute_id('message_text');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_system_message_sender_attribute_id integer := data.get_attribute_id('system_message_sender');
  v_system_message_time_attribute_id integer := data.get_attribute_id('system_message_time');
  v_system_chat_length_attribute_id integer := data.get_attribute_id('system_chat_length');

  v_all_chats_id integer := data.get_object_id('all_chats');

  v_master_group_id integer := data.get_object_id('master');

  v_content text[];
  v_new_content text[];
  v_message_sent boolean := false;

  v_actor_title text := json.get_string(data.get_attribute_value(v_actor_id, v_title_attribute_id));
  v_title text := pp_utils.format_date(clock_timestamp()) || E'\n' || v_actor_title;
  v_notification_text text;

  v_chat_unread_messages integer;
  v_chat_unread_messages_attribute_id integer := data.get_attribute_id('chat_unread_messages');

  v_is_actor_subscribed boolean;
  v_chat_length integer;
  v_chat_parent_list text := json.get_string_opt(data.get_attribute_value(v_chat_id, 'system_chat_parent_list'), '~');
  v_chat_title text;
  v_changes jsonb[];
begin
  assert in_request_id is not null;

  -- Берём имя чата только если оно осознанное
  if json.get_boolean_opt(data.get_attribute_value_for_share(v_chat_id, 'system_chat_is_renamed'), false) then
    v_chat_title := json.get_string_opt(data.get_raw_attribute_value_for_share(v_chat_id, v_title_attribute_id), null);
  end if;
  -- создаём новое сообщение
  insert into data.objects(class_id) values (v_message_class_id) returning id, code into v_message_id, v_message_code;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_message_id, v_title_attribute_id, to_jsonb(v_title), null),
  (v_message_id, v_message_text_attribute_id, to_jsonb(v_message_text), null),
  (v_message_id, v_is_visible_attribute_id, jsonb 'true', v_chat_id),
  (v_message_id, v_system_message_sender_attribute_id, to_jsonb(v_actor_id), null),
  (v_message_id, v_system_message_time_attribute_id, to_jsonb(to_char(clock_timestamp(),'DD.MM.YYYY hh24:mi:ss') ), null);

  -- Добавляем сообщение в чат
  v_changes := array[]::jsonb[];

  -- Достаём, меняем, кладём назад
  v_content := json.get_string_array_opt(data.get_raw_attribute_value_for_update(v_chat_id, v_content_attribute_id), array[]::text[]);
  v_new_content := array_prepend(v_message_code, v_content);
  if v_new_content <> v_content then
    v_chat_length := json.get_integer_opt(data.get_attribute_value_for_update(v_chat_id, v_system_chat_length_attribute_id), null);
    if v_chat_length is not null then
      v_changes := array_append(v_changes, data.attribute_change2jsonb(v_system_chat_length_attribute_id, to_jsonb(v_chat_length + 1)));
    end if;
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_content_attribute_id, to_jsonb(v_new_content)));

    if v_chat_parent_list = 'chats' then
    -- Перекладываем этот чат в начало в списке всех игровых чатов
      perform pp_utils.list_replace_to_head_and_notify(v_all_chats_id, v_chat_code, null);
    end if;
    -- Отправляем нотификацию о новом сообщении всем неподписанным на этот чат
    -- и перекладываем у всех участников этот чат вверх списка
    v_notification_text := 'Новое сообщение ' || (case when v_chat_title is not null then ' в '|| v_chat_title  || ' ' else '' end) || 'от '|| v_actor_title;
    for v_person_id in 
      (select oo.object_id from data.object_objects oo 
        where oo.parent_object_id = v_chat_id
          and oo.parent_object_id <> oo.object_id)
    loop
      v_person_code := data.get_object_code(v_person_id);
      if v_chat_parent_list = 'master_chats' then
        perform pp_utils.list_replace_to_head_and_notify(data.get_object_id(v_person_code || '_master_chats'), v_chat_code, null);
      elsif v_chat_parent_list = 'chats' then
        perform pp_utils.list_replace_to_head_and_notify(data.get_object_id(v_person_code || '_chats'), v_chat_code, null);
      end if;
      v_is_actor_subscribed := pp_utils.is_actor_subscribed(v_person_id, v_chat_id);
      if v_person_id <> v_actor_id
        and not v_is_actor_subscribed then
        v_chat_unread_messages := json.get_integer_opt(data.get_raw_attribute_value_for_update(v_chat_id, v_chat_unread_messages_attribute_id, v_person_id), 0);
        v_changes := array_append(v_changes, data.attribute_change2jsonb(v_chat_unread_messages_attribute_id, to_jsonb(v_chat_unread_messages + 1), v_person_id));
      end if;
      if v_person_id <> v_actor_id
        and not v_is_actor_subscribed
        and v_chat_unread_messages = 0 -- Уведомляем только о первом непрочитанном сообщении
        and not json.get_boolean_opt(data.get_raw_attribute_value_for_share(v_chat_id, 'chat_is_mute', v_person_id), false) then
        perform pp_utils.add_notification(v_person_id, v_notification_text, v_chat_id);
      end if;
    end loop;
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_chat_id, 
                                                 to_jsonb(v_changes));
  end if;

  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language plpgsql;
