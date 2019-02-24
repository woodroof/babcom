-- drop function pallas_project.act_debatle_confirm_presence(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_confirm_presence(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_debatle_code text := json.get_string(in_params, 'debatle_code');
  v_debatle_id  integer := data.get_object_id(v_debatle_code);
  v_master_id integer := data.get_object_id('master');
  v_actor_id  integer := data.get_active_actor_id(in_client_id);

  v_is_visible boolean := json.get_boolean_opt(data.get_attribute_value(v_debatle_id, 'is_visible', v_actor_id), false);
  v_debatle_person1 text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person1'), '~');
  v_debatle_person2 text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person2'), '~');
  v_debatle_judge text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_judge'), '~');

  v_changes jsonb[] := array[]::jsonb[];
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;

  -- Если мы не видим дебатл, надо добавиться в группу
  if not v_is_visible then
    perform data.add_object_to_object(v_actor_id, v_debatle_id);
  end if;

  v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_is_confirmed_presence', jsonb 'true', v_actor_id));
  if data.get_object_code(v_actor_id) not in (v_debatle_person1, v_debatle_person2, v_debatle_judge) then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_my_vote', jsonb '"Вы не голосовали"', v_actor_id));
  end if;


  perform data.change_object_and_notify(v_debatle_id, 
                                        to_jsonb(v_changes),
                                        v_actor_id);

  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_debatle_code);
end;
$$
language plpgsql;
