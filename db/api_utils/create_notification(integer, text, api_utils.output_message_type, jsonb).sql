-- drop function api_utils.create_notification(integer, text, api_utils.output_message_type, jsonb);

create or replace function api_utils.create_notification(in_client_id integer, in_request_id text, in_type api_utils.output_message_type, in_data jsonb)
returns void
volatile
as
$$
declare
  v_message jsonb :=
    jsonb_build_object(
      'type', in_type::text,
      'data', json.get_object(in_data)) ||
    (case when in_request_id is not null then jsonb_build_object('request_id', in_request_id) else jsonb '{}' end);
  v_notification_code text;
begin
  assert in_client_id is not null;
  assert in_type is not null;

  insert into data.notifications(message, client_id)
  values(v_message, in_client_id)
  returning code into v_notification_code;

  perform pg_notify('api_channel', v_notification_code);
end;
$$
language plpgsql;
