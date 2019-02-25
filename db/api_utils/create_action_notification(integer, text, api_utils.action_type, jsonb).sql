-- drop function api_utils.create_action_notification(integer, text, api_utils.action_type, jsonb);

create or replace function api_utils.create_action_notification(in_client_id integer, in_request_id text, in_action_type api_utils.action_type, in_action_data jsonb)
returns void
volatile
as
$$
begin
  assert json.is_object(in_action_data);

  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'action',
    jsonb_build_object('action', in_action_type, 'action_data', in_action_data));
end;
$$
language plpgsql;
