-- drop function api.disconnect_all_clients();

create or replace function api.disconnect_all_clients()
returns void
volatile
security definer
as
$$
begin
  delete from data.notifications;
  delete from data.client_subscription_objects;
  delete from data.client_subscriptions;

  update data.clients
  set
    is_connected = false,
    actor_id = null;

  perform data.log('info', 'All clients were disconnected');
end;
$$
language plpgsql;
