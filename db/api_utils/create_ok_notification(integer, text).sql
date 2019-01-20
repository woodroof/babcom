-- drop function api_utils.create_ok_notification(integer, text);

create or replace function api_utils.create_ok_notification(in_client_id integer, in_request_id text)
returns void
volatile
as
$$
begin
  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'ok',
    jsonb '{}');
end;
$$
language plpgsql;
