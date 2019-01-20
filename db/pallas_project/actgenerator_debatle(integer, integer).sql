-- drop function pallas_project.actgenerator_debatle(integer, integer);

create or replace function pallas_project.actgenerator_debatle(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_person1_id integer;
  v_is_master boolean;
  v_debatle_code text;
  v_debatle_status text;
begin
  assert in_actor_id is not null;

  v_is_master := pallas_project.is_in_group(in_actor_id, 'master');
  v_debatle_code := data.get_object_code(in_object_id);
  v_person1_id := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person1'), null);
  v_debatle_status := json.get_string_opt(data.get_attribute_value(in_object_id, 'debatle_status'), null);

  if v_is_master then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_instigator": {"code": "debatle_change_person", "name": "Изменить зачинщика", "disabled": false, '||
                '"params": {"debatle_code": "%s", "edited_person": "instigator"}}',
                v_debatle_code);
  end if;

  if v_is_master or in_actor_id = v_person1_id and v_debatle_status in ('draft') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_opponent": {"code": "debatle_change_person", "name": "Изменить оппонента", "disabled": false, '||
                '"params": {"debatle_code": "%s", "edited_person": "opponent"}}',
                v_debatle_code);
  end if;

  if v_is_master then
      v_actions_list := v_actions_list || 
        format(', "debatle_change_judge": {"code": "debatle_change_person", "name": "Изменить судью", "disabled": false, '||
                '"params": {"debatle_code": "%s", "edited_person": "judge"}}',
                v_debatle_code);
  end if;

  if v_is_master or in_actor_id = v_person1_id and v_debatle_status in ('draft') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_theme": {"code": "debatle_change_theme", "name": "Изменить тему", "disabled": false, '||
                '"params": {"debatle_code": "%s"}, "user_params": [{"code": "title", "description": "Введите тему дебатла", "type": "string" }]}',
                v_debatle_code);
  end if;

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
