-- drop function pallas_project.actgenerator_debatle_target_audience_content(integer, integer, integer);

create or replace function pallas_project.actgenerator_debatle_target_audience_content(in_object_id integer, in_list_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_is_master boolean;
  v_master_group_id integer := data.get_object_id('master');
  v_debatle_code text := replace(data.get_object_code(in_object_id), '_target_audience', '');
  v_debatle_id integer := data.get_object_id(v_debatle_code);
  v_list_code text := data.get_object_code(in_list_object_id);
  v_debatle_status text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_status'),'');
  v_system_debatle_target_audience text[] := json.get_string_array_opt(data.get_attribute_value_for_share(in_object_id, 'system_debatle_target_audience'), array[]::text[]);
  v_is_in_array boolean;
begin
  assert in_actor_id is not null;

  v_is_master := pp_utils.is_in_group(in_actor_id, 'master');
  if v_debatle_status in ('draft', 'new') then
    v_is_in_array := (array_position(v_system_debatle_target_audience, v_list_code) is not null);
    v_actions_list := v_actions_list ||
            format(', "debatle_del_audience_group": {"code": "debatle_change_audience_group", "name": "-", "disabled": %s, '||
                    '"params": {"debatle_code": "%s", "list_code": "%s", "add_or_del": "del"}}',
                    case when v_is_in_array then 'false' else 'true' end,
                    v_debatle_code,
                    v_list_code);
      v_actions_list := v_actions_list || 
            format(', "debatle_add_audience_group": {"code": "debatle_change_audience_group", "name": "+", "disabled": %s, '||
                    '"params": {"debatle_code": "%s", "list_code": "%s", "add_or_del": "add"}}',
                    case when v_is_in_array then 'true' else 'false' end,
                    v_debatle_code,
                    v_list_code);
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
