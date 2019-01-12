-- drop function test_project.one_simple_action(integer, integer);

create or replace function test_project.one_simple_action(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  return jsonb_build_object(
    v_object_code || '_action',
    jsonb '{"code": "do_nothing", "name": "Не тыкай сюда!", "disabled": false, "params": {}}');
end;
$$
language 'plpgsql';
