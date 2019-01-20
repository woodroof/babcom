-- drop function data.set_login(integer, integer);

create or replace function data.set_login(in_client_id integer, in_login_id integer)
returns void
volatile
as
$$
declare
  v_is_connected boolean;
begin
  update data.clients
  set
    login_id = in_login_id,
    actor_id = null
  where id = in_client_id
  returning is_connected
  into v_is_connected;

  assert v_is_connected is not null;

  if v_is_connected then
    delete from data.client_subscription_objects
    where client_subscription_id in (
      select id
      from data.client_subscriptions
      where client_id = in_client_id);

    delete from data.client_subscriptions
    where client_id = in_client_id;
  end if;
end;
$$
language 'plpgsql';
