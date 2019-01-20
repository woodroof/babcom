-- drop function test_project.object_action_generator(integer, integer);

create or replace function test_project.object_action_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  return format('{"%s_action": {"code": "do_nothing", "name": "Не тыкай сюда!", "disabled": false, "params": null}}', v_object_code)::jsonb;
end;
$$
language plpgsql;
