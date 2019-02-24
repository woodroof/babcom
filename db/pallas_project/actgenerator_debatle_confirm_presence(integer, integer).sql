-- drop function pallas_project.actgenerator_debatle_confirm_presence(integer, integer);

create or replace function pallas_project.actgenerator_debatle_confirm_presence(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_debatle_code text := data.get_object_code(json.get_integer(data.get_attribute_value(in_object_id, 'system_debatle_id')));
begin
  assert in_actor_id is not null;

  v_actions_list := v_actions_list || 
                format(', "debatle_confirm_presence": {"code": "debatle_confirm_presence", "name": "Перейти к дебатлу", "disabled": false, ' ||
                '"params": {"debatle_code": "%s"}}',
                v_debatle_code);

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
