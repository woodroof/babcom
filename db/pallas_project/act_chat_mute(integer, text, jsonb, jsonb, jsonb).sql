-- drop function pallas_project.act_chat_mute(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_chat_mute(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_chat_code text := json.get_string(in_params, 'chat_code');
  v_mute_on_off text := json.get_string(in_params, 'mute_on_off');
  v_chat_id integer := data.get_object_id(v_chat_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_chat_is_mute boolean;
  v_new_chat_is_mute boolean;

  v_chat_is_mute_attribute_id integer := data.get_attribute_id('chat_is_mute');
  v_message_sent boolean := false;
begin
  -- mute_on_off: on - заглушить уведомления, off - перестать глушить уведомления
  assert in_request_id is not null;
  assert v_mute_on_off in ('on', 'off');

  perform * from data.objects where id = v_chat_id for update;

  v_chat_is_mute := json.get_boolean_opt(data.get_attribute_value(v_chat_id, v_chat_is_mute_attribute_id, v_actor_id), false);

  if not v_chat_is_mute and v_mute_on_off = 'on' then
  -- проверяем, что отключать можно
    assert json.get_boolean_opt(data.get_attribute_value(v_actor_id, 'system_chat_can_mute', v_actor_id), true);
  end if;

  if v_mute_on_off = 'on' then
    v_new_chat_is_mute := true;
  end if;

  if coalesce(v_new_chat_is_mute, false) <> v_chat_is_mute then
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_chat_id, 
                                                 jsonb_build_array(data.attribute_change2jsonb(v_chat_is_mute_attribute_id, v_actor_id, to_jsonb(v_new_chat_is_mute))));
  end if;
  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language plpgsql;
