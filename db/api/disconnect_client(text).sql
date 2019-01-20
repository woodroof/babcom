-- drop function api.disconnect_client(text);

create or replace function api.disconnect_client(in_client_code text)
returns void
volatile
security definer
as
$$
declare
  v_client_id integer;
begin
  assert in_client_code is not null;

  select id
  into v_client_id
  from data.clients
  where
    code = in_client_code and
    is_connected = true
  for update;

  if v_client_id is null then
    raise exception 'Client with code "%" is not connected', in_client_code;
  end if;

  update data.clients
  set
    is_connected = false,
    actor_id = null
  where id = v_client_id;

  delete from data.notifications
  where client_id = v_client_id;

  delete from data.client_subscription_objects
  where client_subscription_id in (
    select id
    from data.client_subscriptions
    where client_id = v_client_id);

  delete from data.client_subscriptions
  where client_id = v_client_id;

  perform data.log('info', format('Disconnected client with code "%s"', in_client_code));
end;
$$
language plpgsql;
