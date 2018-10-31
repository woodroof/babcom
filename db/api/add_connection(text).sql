-- drop function api.add_connection(text);

create or replace function api.add_connection(in_client_id text)
returns void
volatile
as
$$
begin
	insert into data.connections(client_id)
	values(in_client_id);
end;

$$
language 'plpgsql';
