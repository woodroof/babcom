-- drop function test_project.do_nothing_action(integer, text, jsonb, jsonb);

create or replace function test_project.do_nothing_action(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
begin
  assert in_request_id is not null;
  assert in_params = jsonb '{}';
  assert in_user_params is null;

  perform api_utils.create_notification(in_client_id, in_request_id, 'action', jsonb '{"action": "do_nothing"}');
end;
$$
language 'plpgsql';
