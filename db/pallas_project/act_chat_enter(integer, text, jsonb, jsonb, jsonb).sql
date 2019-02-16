-- drop function pallas_project.act_chat_enter(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_chat_enter(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string_opt(in_params, 'object_code', null);
  v_chat_code text := json.get_string_opt(in_params, 'chat_code', null);
  v_goto_chat boolean := json.get_boolean_opt(in_params, 'goto_chat', false);
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_chat_id integer;
  v_chat_parent_list text;

  v_name jsonb;
  v_chat_title text := '';
  v_chat_is_renamed boolean;
  v_chat_unread_messages_attribute_id integer := data.get_attribute_id('chat_unread_messages');

  v_chats_id integer := data.get_object_id('chats');
  v_master_chats_id integer := data.get_object_id('master_chats');

  v_is_master boolean := pp_utils.is_in_group(v_actor_id, 'master');
  v_changes jsonb[];
begin
  assert in_request_id is not null;
  assert v_object_code is not null or v_chat_code is not null;

  if v_object_code is not null then
    v_chat_id  := data.get_object_id(v_object_code || '_chat') ;
    v_chat_code := data.get_object_code(v_chat_id);
  elsif v_chat_code is not null then
    v_chat_id := data.get_object_id(v_chat_code);
  end if;

  v_chat_parent_list := json.get_string_opt(data.get_attribute_value(v_chat_id, 'system_chat_parent_list'), '~');

  --Проверяем, может мы уже в этом чате, тогда ничего делать не надо, только перейти
  if not pp_utils.is_in_group(v_actor_id, v_chat_code) then
  -- добавляем в группу с рассылкой
    perform data.process_diffs_and_notify(data.change_object_groups(v_actor_id, array[v_chat_id], array[]::integer[], v_actor_id));

    -- Меняем заголовок чата, если зашёл не мастер
    if not v_is_master or v_chat_parent_list = 'master_chats' then
      for v_name in 
        (select x.name from jsonb_to_recordset(pallas_project.get_chat_persons(v_chat_id, v_chat_parent_list <> 'master_chats'))as x(code text, name jsonb) limit 3) loop 
        v_chat_title := v_chat_title || ', '|| json.get_string(v_name);
      end loop;

      v_chat_title := trim(v_chat_title, ', ');
      perform * from data.objects where id = v_chat_id for update;

      v_changes := array[]::jsonb[];
      v_chat_is_renamed := json.get_boolean_opt(data.get_attribute_value(v_chat_id, 'system_chat_is_renamed'), false);
      if not v_chat_is_renamed then 
        v_changes := array_append(v_changes, data.attribute_change2jsonb('title', to_jsonb(v_chat_title)));
      else
        v_changes := array_append(v_changes, data.attribute_change2jsonb('subtitle', to_jsonb(v_chat_title)));
      end if;

      if v_object_code is not null or v_goto_chat then
        perform data.change_object_and_notify(v_chat_id, 
                                              to_jsonb(v_changes),
                                              null);
      else
        -- если мы заходили из самого чата, то надо прислать обновления себе
        perform data.change_current_object(in_client_id, 
                                           in_request_id, 
                                           v_chat_id, 
                                           to_jsonb(v_changes));
      end if;
      -- Меняем привязанный к чату список для участников
      perform pallas_project.change_chat_person_list_on_person(v_chat_id, case when not v_chat_is_renamed then v_chat_title else null end, (v_chat_parent_list = 'master_chats'));
    end if;

    if v_chat_parent_list = 'master_chats' then
      if not v_is_master then
        perform pp_utils.list_prepend_and_notify(v_master_chats_id, v_chat_code, v_actor_id);
      end if;
    elsif v_chat_parent_list = 'chats' then
      perform pp_utils.list_prepend_and_notify(v_chats_id, v_chat_code, v_actor_id);
    end if;
  end if;

  -- Переходим к чату или остаёмся на нём
  if v_object_code is not null or v_goto_chat then
    perform data.change_object_and_notify(v_chat_id, 
                                          jsonb_build_array(data.attribute_change2jsonb(v_chat_unread_messages_attribute_id, null, v_actor_id)),
                                          v_actor_id);

    perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_chat_code);
  else
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
