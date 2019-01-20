-- drop function pallas_project.act_go_back(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_go_back(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
begin
  assert in_request_id is not null;

  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'action',
    '{"action": "go_back", "action_data": {}}'::jsonb);
end;
$$
language plpgsql;
