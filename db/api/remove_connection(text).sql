-- drop function api.remove_connection(text);

create or replace function api.remove_connection(in_client_id text)
returns void
volatile
as
$$
begin
  delete from data.notifications
  where client_id = in_client_id;

  delete from data.connections
  where client_id = in_client_id;
end;
$$
language 'plpgsql';
