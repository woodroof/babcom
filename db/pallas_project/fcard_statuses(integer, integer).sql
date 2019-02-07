-- drop function pallas_project.fcard_statuses(integer, integer);

create or replace function pallas_project.fcard_statuses(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_cycle_number integer := data.get_integer_param('economic_cycle_number');
begin
  assert in_actor_id is not null;

  perform data.change_object_and_notify(
    in_object_id,
    jsonb '[]' ||
    data.attribute_change2jsonb('subtitle', null, to_jsonb(v_cycle_number || ' цикл')),
    in_actor_id);
end;
$$
language plpgsql;
