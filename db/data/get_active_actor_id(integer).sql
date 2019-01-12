-- drop function data.get_active_actor_id(integer);

create or replace function data.get_active_actor_id(in_client_id integer)
returns integer
volatile
as
$$
declare
  v_actor_id integer;
begin
  assert in_client_id is not null;

  select actor_id
  into v_actor_id
  from data.clients
  where id = in_client_id;

  assert v_actor_id is not null;

  return v_actor_id;
end;
$$
language 'plpgsql';
