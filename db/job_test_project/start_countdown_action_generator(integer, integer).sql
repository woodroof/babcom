-- drop function job_test_project.start_countdown_action_generator(integer, integer);

create or replace function job_test_project.start_countdown_action_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_state text := json.get_string(data.get_attribute_value(in_object_id, 'state', in_actor_id));
begin
  if v_state = 'state1' then
    return format('{"action": {"code": "start_countdown", "name": "Поехали!", "disabled": false, "params": %s}}', in_object_id)::jsonb;
  end if;

  return jsonb '{}';
end;
$$
language plpgsql;
