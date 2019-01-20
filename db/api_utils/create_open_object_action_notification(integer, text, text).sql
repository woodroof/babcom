-- drop function api_utils.create_open_object_action_notification(integer, text, text);

create or replace function api_utils.create_open_object_action_notification(in_client_id integer, in_request_id text, in_object_code text)
returns void
volatile
as
$$
begin
  perform data.get_object_id(in_object_code);

  perform api_utils.create_action_notification(
    in_client_id,
    in_request_id,
    'open_object',
    jsonb_build_object('object_id', in_object_code));
end;
$$
language 'plpgsql';
