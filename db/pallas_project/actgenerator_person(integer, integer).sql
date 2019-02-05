-- drop function pallas_project.actgenerator_person(integer, integer);

create or replace function pallas_project.actgenerator_person(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
begin
  return jsonb '{}';
end;
$$
language plpgsql;
