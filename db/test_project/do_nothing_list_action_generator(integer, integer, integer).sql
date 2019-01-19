-- drop function test_project.do_nothing_list_action_generator(integer, integer, integer);

create or replace function test_project.do_nothing_list_action_generator(in_object_id integer, in_list_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_title_attribute jsonb := data.get_attribute_value(in_list_object_id, 'title', in_actor_id);
begin
  assert data.is_instance(in_object_id);

  if v_title_attribute = jsonb '"Duo"' then
    return jsonb '{"action": {"code": "do_nothing", "name": "Я кнопка", "disabled": false, "params": null}}';
  end if;

  return jsonb '{}';
end;
$$
language 'plpgsql';
