-- drop function api.add_connection(text);

create or replace function api.add_connection(in_client_id text)
returns void
volatile
as
$$
begin
  assert in_client_id is not null;

  insert into data.connections(client_id)
  values(in_client_id);
exception when unique_violation then
  raise exception 'Client with id "%" already connected', in_client_id;
end;
$$
language 'plpgsql';
