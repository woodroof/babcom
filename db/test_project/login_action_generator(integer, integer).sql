-- drop function test_project.login_action_generator(integer, integer);

create or replace function test_project.login_action_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_title text := json.get_string(data.get_attribute_value(in_object_id, 'title', in_actor_id));
begin
  return format('{"action": {"code": "login", "name": "Далее", "disabled": false, "params": "%s"}}', v_title)::jsonb;
end;
$$
language plpgsql;
