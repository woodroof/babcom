-- drop function pallas_project.actgenerator_customs_future_content(integer, integer, integer);

create or replace function pallas_project.actgenerator_customs_future_content(in_object_id integer, in_list_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_object_code text := data.get_object_code(in_list_object_id);
  v_list_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  if pp_utils.is_in_group(in_actor_id, 'master') then
    v_actions_list := v_actions_list || 
      format(', "customs_package_delete": {"code": "customs_package_delete", "name": "Удалить", "disabled": false, "warning": "Груз безвозвратно исчезнет из всех списков",
      "params": {"package_code": "%s", "from_list": "%s"}}',
      v_object_code,
      v_list_code);
  end if;

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
