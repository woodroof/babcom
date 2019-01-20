-- drop function test_project.next_action_with_array_params(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.next_action_with_array_params(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_array jsonb := json.get_array(in_params);
  v_array_len integer := jsonb_array_length(v_array);
  v_object_code text;
begin
  perform data.get_active_actor_id(in_client_id);

  assert in_request_id is not null;
  assert test_project.is_user_params_empty(in_user_params);
  assert in_default_params is null;

  assert v_array_len = 1;

  v_object_code := json.get_string(v_array->0);

  perform api_utils.create_open_object_action_notification(
    in_client_id,
    in_request_id,
    test_project.next_code(v_object_code));
end;
$$
language 'plpgsql';
