-- drop function api_utils.create_go_back_action_notification(integer, text);

create or replace function api_utils.create_go_back_action_notification(in_client_id integer, in_request_id text)
returns void
volatile
as
$$
begin
  perform api_utils.create_action_notification(
    in_client_id,
    in_request_id,
    'go_back',
    jsonb '{}');
end;
$$
language plpgsql;
