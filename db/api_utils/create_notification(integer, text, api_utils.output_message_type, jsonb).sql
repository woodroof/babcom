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
  v_client_code text;
begin
  assert in_client_id is not null;
  assert in_type is not null;

  insert into data.notifications(type, message, client_id)
  values('client_message', v_message, in_client_id)
  returning code into v_notification_code;

  select code
  into v_client_code
  from data.clients
  where id = in_client_id;

  perform pg_notify('api_channel', jsonb_build_object('notification_code', v_notification_code, 'client_code', v_client_code)::text);
end;
$$
language plpgsql;
