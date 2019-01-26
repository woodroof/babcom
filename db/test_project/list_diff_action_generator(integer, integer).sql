-- drop function test_project.list_diff_action_generator(integer, integer);

create or replace function test_project.list_diff_action_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;
  return format('{"action": {"code": "list_diff", "name": "Далее", "disabled": false, "params": "%s"}}', v_object_code)::jsonb;
end;
$$
language plpgsql;
