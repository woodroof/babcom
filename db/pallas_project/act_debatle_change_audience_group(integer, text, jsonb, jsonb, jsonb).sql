-- drop function pallas_project.act_debatle_change_audience_group(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_change_audience_group(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_debatle_code text := json.get_string(in_params, 'debatle_code');
  v_list_code text := json.get_string(in_params, 'list_code');
  v_add_or_del text := json.get_string(in_params, 'add_or_del');

  v_debatle_change_id integer := data.get_object_id(v_debatle_code || '_target_audience');
  v_debatle_id integer := data.get_object_id(v_debatle_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_list_id integer := data.get_object_id(v_list_code);

  v_system_debatle_target_audience text[] := json.get_string_array_opt(data.get_attribute_value_for_update(v_debatle_id, 'system_debatle_target_audience'), array[]::text[]);
  v_debatle_person1 text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person1'), null);
  v_debatle_target_audience text;

  v_changes jsonb[];
  v_message_sent boolean;
begin
  assert in_request_id is not null;
  assert v_add_or_del in ('add', 'del');

  if v_add_or_del = 'add' then
    v_system_debatle_target_audience := array_append(v_system_debatle_target_audience, v_list_code);
    perform data.add_object_to_object(v_list_id, v_debatle_id);
  else
    v_system_debatle_target_audience := array_remove(v_system_debatle_target_audience, v_list_code);
    perform data.remove_object_from_object(v_list_id, v_debatle_id);
  end if;

  v_debatle_target_audience := pallas_project.get_debatle_target_audience(v_system_debatle_target_audience);

  v_changes := array[]::jsonb[];
  v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_target_audience', to_jsonb(v_debatle_target_audience), 'master'));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_target_audience', to_jsonb(v_debatle_target_audience), v_debatle_person1));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_target_audience', to_jsonb(v_system_debatle_target_audience)));

  perform data.change_object_and_notify(v_debatle_id, to_jsonb(v_changes), v_actor_id);

  v_changes := array[]::jsonb[];
  v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_target_audience', to_jsonb(v_debatle_target_audience)));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_target_audience', to_jsonb(v_system_debatle_target_audience)));
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               v_debatle_change_id, 
                                               to_jsonb(v_changes));
  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
