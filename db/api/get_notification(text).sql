-- drop function api.get_notification(text);

create or replace function api.get_notification(in_notification_code text)
returns jsonb
volatile
as
$$
declare
  v_message text;
  v_connection_id integer;
  v_client_id text;
begin
  assert in_notification_code is not null;

  delete from data.notifications
  where code = in_notification_code
  returning message, connection_id
  into v_message, v_connection_id;

  if v_connection_id is null then
    raise exception 'Can''t find notification with code "%"', in_notification_code;
  end if;

  select client_id
  into v_client_id
  from data.connections
  where id = v_connection_id;

  assert v_client_id is not null;

  return jsonb_build_object(
    'client_id',
    v_client_id,
    'message',
    v_message);
end;
$$
language 'plpgsql';
