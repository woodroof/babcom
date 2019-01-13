-- drop function test_project.simple_action_generator(integer, integer);

create or replace function test_project.simple_action_generator(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
begin
  perform data.get_object_code(in_object_id);
  assert in_actor_id is not null;

  return jsonb '{"action": {"code": "do_nothing", "name": "Не тыкай сюда!", "disabled": false, "params": null}}';
end;
$$
language 'plpgsql';
