-- drop function api.disconnect_all_clients();

create or replace function api.disconnect_all_clients()
returns void
volatile
security definer
as
$$
declare
  v_metric record;
begin
  delete from data.notifications;
  delete from data.client_subscription_objects;
  delete from data.client_subscriptions;

  update data.clients
  set
    is_connected = false,
    actor_id = null;

  for v_metric in
  (
    select type, value
    from data.metrics
  )
  loop
    perform api_utils.create_metric_notification(v_metric.type, v_metric.value);
  end loop;

  perform data.log('info', 'All clients were disconnected');
end;
$$
language plpgsql;
