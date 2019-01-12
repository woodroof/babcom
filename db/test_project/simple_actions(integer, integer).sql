-- drop function test_project.simple_actions(integer, integer);

create or replace function test_project.simple_actions(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  return jsonb_build_object(
    v_object_code || '_unnamed',
    jsonb '{"code": "do_nothing", "disabled": false, "params": {}}',
    v_object_code || '_named',
    jsonb '{"code": "do_nothing", "name": "Действие", "disabled": false, "params": {}}',
    v_object_code || '_disabled',
    jsonb '{"code": "do_nothing", "name": "Заблокированное действие", "disabled": true}');
end;
$$
language 'plpgsql';
