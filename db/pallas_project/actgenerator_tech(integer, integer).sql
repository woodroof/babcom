-- drop function pallas_project.actgenerator_tech(integer, integer);

create or replace function pallas_project.actgenerator_tech(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_is_master boolean;
  v_tech_skill integer := json.get_integer_opt(data.get_attribute_value_for_share(in_actor_id, 'system_person_tech_skill'), null);
  v_tech_broken text := json.get_string(data.get_attribute_value_for_update(in_object_id, 'tech_broken'));
  v_tech_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  v_is_master := pp_utils.is_in_group(in_actor_id, 'master');

  if v_is_master and v_tech_broken in ('working') then
    v_actions_list := v_actions_list || 
          format(', "tech_break": {"code": "tech_break", "name": "Сломать", "disabled": false,'||
                  '"params": {"tech_code": "%s"}}',
                  v_tech_code);
  end if;

  if (v_is_master or v_tech_skill is not null) and v_tech_broken in ('broken') then
    v_actions_list := v_actions_list || 
          format(', "tech_repare": {"code": "tech_repare", "name": "Починить", "disabled": false,'||
                  '"params": {"tech_code": "%s"}}',
                  v_tech_code);
  end if;

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
