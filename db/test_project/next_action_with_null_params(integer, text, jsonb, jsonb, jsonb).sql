-- drop function test_project.next_action_with_null_params(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.next_action_with_null_params(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_default_params, 'object_code');
begin
  perform data.get_active_actor_id(in_client_id);

  assert in_request_id is not null;
  assert in_params = jsonb 'null';
  assert test_project.is_user_params_empty(in_user_params);

  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'action',
    format('{"action": "open_object", "action_data": {"object_id": "%s"}}', test_project.next_code(v_object_code))::jsonb);
end;
$$
language 'plpgsql';