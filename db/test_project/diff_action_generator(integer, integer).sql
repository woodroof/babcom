-- drop function test_project.diff_action_generator(integer, integer);

create or replace function test_project.diff_action_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_state text := json.get_string(data.get_attribute_value(in_object_id, 'test_state'));
  v_name text := case when v_state = 'state2' then 'Вперёд!' else 'Далее' end;
  v_title text := json.get_string(data.get_attribute_value(in_object_id, 'title', in_actor_id));
begin
  return format('{"action": {"code": "diff", "name": "%s", "disabled": false, "params": {"title": "%s", "object_id": %s}}}', v_name, v_title, in_object_id)::jsonb;
end;
$$
language plpgsql;
