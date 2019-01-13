-- drop function test_project.next_action_with_null_params_generator(integer, integer);

create or replace function test_project.next_action_with_null_params_generator(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
begin
  assert data.get_object_code(in_object_id) is not null;
  assert in_actor_id is not null;

  return jsonb '{"action": {"code": "next_action_with_null_params", "name": "Далее", "disabled": false, "params": null}}';
end;
$$
language 'plpgsql';
