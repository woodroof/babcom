-- drop function pallas_project.mcard_person(integer, integer);

create or replace function pallas_project.mcard_person(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_value jsonb;
  v_is_master boolean;
  v_changes jsonb[];
begin

  null;

end;
$$
language 'plpgsql';
