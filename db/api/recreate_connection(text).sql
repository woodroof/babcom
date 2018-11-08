-- drop function api.recreate_connection(text);

create or replace function api.recreate_connection(in_client_id text)
returns void
volatile
as
$$
begin
  delete from data.notifications
  where client_id = in_client_id;
end;
$$
language 'plpgsql';