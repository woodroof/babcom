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

  v_changes jsonb[] := array[]::jsonb[];
  v_person_id integer;

  v_message_sent boolean := false;
begin
  assert in_request_id is not null;
  assert v_parameter in ('can_leave', 'can_invite', 'can_mute', 'can_rename');
  assert v_value in ('on', 'off');

  perform * from data.objects where id = v_chat_id for update;

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

  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language plpgsql;
