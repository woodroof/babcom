-- drop function api.get_notification(text);

create or replace function api.get_notification(in_notification_code text)
returns jsonb
volatile
security definer
as
$$
declare
  v_message text;
  v_client_id integer;
  v_client_code text;
begin
  assert in_notification_code is not null;

  delete from data.notifications
  where code = in_notification_code
  returning message, client_id
  into v_message, v_client_id;

  if v_client_id is null then
    raise exception 'Can''t find notification with code "%"', in_notification_code;
  end if;

  select code
  into v_client_code
  from data.clients
  where id = v_client_id;

  assert v_client_code is not null;

  return jsonb_build_object(
    'client_code',
    v_client_code,
    'message',
    v_message);
end;
$$
language plpgsql;
