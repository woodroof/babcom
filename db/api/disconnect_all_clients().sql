-- drop function api.disconnect_all_clients();

create or replace function api.disconnect_all_clients()
returns void
volatile
as
$$
begin
  delete from data.notifications;

  update data.clients
  set
    is_connected = false,
    actor_id = null;

  perform data.log('info', 'All clients were disconnected');
end;
$$
language 'plpgsql';
