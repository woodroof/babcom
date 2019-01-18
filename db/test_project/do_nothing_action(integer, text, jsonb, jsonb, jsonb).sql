-- drop function test_project.do_nothing_action(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.do_nothing_action(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
begin
  perform data.get_active_actor_id(in_client_id);

  assert in_request_id is not null;
  assert in_params = jsonb 'null';
  assert test_project.is_user_params_empty(in_user_params);
  assert in_default_params is null;

  perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
end;
$$
language 'plpgsql';
