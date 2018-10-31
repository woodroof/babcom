-- drop function api.remove_all_connections();

create or replace function api.remove_all_connections()
returns void
volatile
as
$$
begin
  delete from data.notifications;
	delete from data.connections;
end;
$$
language 'plpgsql';
