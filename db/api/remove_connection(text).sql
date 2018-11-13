-- drop function api.remove_connection(text);

create or replace function api.remove_connection(in_client_id text)
returns void
volatile
as
$$
declare
  v_connection_id integer;
begin
  assert in_client_id is not null;

  select id
  into v_connection_id
  from data.connections
  where client_id = in_client_id;

  if v_connection_id is null then
    raise exception 'Client with id "%" is not connected', in_client_id;
  end if;

  delete from data.notifications
  where connection_id = v_connection_id;

  delete from data.connections
  where id = v_connection_id;
end;
$$
language 'plpgsql';
