-- drop function api.remove_connection(text);

create or replace function api.remove_connection(in_client_id text)
returns void
volatile
as
$$
declare
  v_connection_id integer;
begin
  select id
  into v_connection_id
  from data.connections
  where client_id = in_client_id;

  delete from data.notifications
  where connection_id = v_connection_id;

  delete from data.connections
  where id = v_connection_id;
end;
$$
language 'plpgsql';
