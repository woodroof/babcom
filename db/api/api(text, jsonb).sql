-- drop function api.api(text, jsonb);

create or replace function api.api(in_client_id text, in_message jsonb)
returns void
volatile
as
$$
declare
  v_connection_id integer;
  v_notification_code text;
  v_message jsonb :=
    jsonb_build_object(
      'type',
      'test',
      'data',
      jsonb_build_object(
        'client_id',
        in_client_id,
        'message',
        in_message));
begin
  assert in_client_id is not null;
  assert in_message is not null;

  for v_connection_id in
  (
    select id
    from data.connections
  )
  loop
    insert into data.notifications(message, connection_id)
    values (v_message, v_connection_id)
    returning code into v_notification_code;

    perform pg_notify('api_channel', v_notification_code);
  end loop;
end;
$$
language 'plpgsql';
