-- drop function pallas_project.act_chat_change_settings(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_chat_change_settings(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_chat_code text := json.get_string(in_params, 'chat_code');
  v_parameter text := json.get_string(in_params, 'parameter');
  v_value text := json.get_string(in_params, 'value');
  v_chat_id integer := data.get_object_id(v_chat_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_master_group_id integer := data.get_object_id('master');
  v_chat_person_list_id integer := data.get_object_id(v_chat_code || '_person_list');

  v_changes jsonb[] := array[]::jsonb[];
  v_person_id integer;
  v_content text[];
  v_chat_parent_list text := json.get_string_opt(data.get_attribute_value(v_chat_id, 'system_chat_parent_list'), '~');
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;
  assert v_parameter in ('can_leave', 'can_invite', 'can_mute', 'can_rename');
  assert v_value in ('on', 'off');

  if v_parameter = 'can_leave' then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('system_chat_can_leave', case v_value when 'on' then null else to_jsonb(false) end));
  end if;
  if v_parameter = 'can_invite' then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('system_chat_can_invite', case v_value when 'on' then null else to_jsonb(false) end));
  end if;
  if v_parameter = 'can_mute' then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('system_chat_can_mute', case v_value when 'on' then null else to_jsonb(false) end));
    if v_value = 'off' then
      for v_person_id in 
        (select oo.object_id from data.object_objects oo 
         where oo.parent_object_id = v_chat_id
           and oo.parent_object_id <> oo.object_id)
      loop
        v_changes := array_append(v_changes, data.attribute_change2jsonb('chat_is_mute', null, v_person_id));
      end loop;
    end if;
  end if;
  if v_parameter = 'can_rename' then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('system_chat_can_rename', case v_value when 'on' then null else to_jsonb(false) end));
  end if;

  if array_length(v_changes, 1) > 0 then
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_chat_id, 
                                                 to_jsonb(v_changes));
  end if;

  if v_parameter = 'can_invite' then 
    v_content := pallas_project.get_chat_possible_persons(v_chat_id, (v_chat_parent_list = 'master_chats'));
    v_changes := array[]::jsonb[];
    if v_value = 'on' then
        v_changes := array_append(v_changes, data.attribute_change2jsonb('content', to_jsonb(v_content), v_master_group_id));
        v_changes := array_append(v_changes, data.attribute_change2jsonb('content', to_jsonb(v_content), v_chat_id));
        v_changes := array_append(v_changes, data.attribute_change2jsonb('chat_person_list_content_label', to_jsonb('-------------------------------
Кого добавляем?'::text), v_master_group_id));
        v_changes := array_append(v_changes, data.attribute_change2jsonb('chat_person_list_content_label', to_jsonb('-------------------------------
Кого добавляем?'::text), v_chat_id));
      elsif v_chat_parent_list <> 'master_chats' then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('content', to_jsonb(v_content), v_master_group_id));
      v_changes := array_append(v_changes, data.attribute_change2jsonb('content', null, v_chat_id));
      v_changes := array_append(v_changes, data.attribute_change2jsonb('chat_person_list_content_label', to_jsonb('-------------------------------
Кого добавляем?'::text), v_master_group_id));
      v_changes := array_append(v_changes, data.attribute_change2jsonb('chat_person_list_content_label', null, v_chat_id));
    else
      v_changes := array_append(v_changes, data.attribute_change2jsonb('content', null, v_master_group_id));
      v_changes := array_append(v_changes, data.attribute_change2jsonb('content', null, v_chat_id));
      v_changes := array_append(v_changes, data.attribute_change2jsonb('chat_person_list_content_label', null, v_master_group_id));
      v_changes := array_append(v_changes, data.attribute_change2jsonb('chat_person_list_content_label', null, v_chat_id));
    end if;
    perform data.change_object_and_notify(v_chat_person_list_id, 
                                          to_jsonb(v_changes),
                                          v_actor_id);
  end if;

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
