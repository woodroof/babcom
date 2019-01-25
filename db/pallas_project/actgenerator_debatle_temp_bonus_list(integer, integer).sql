-- drop function pallas_project.actgenerator_debatle_temp_bonus_list(integer, integer);

create or replace function pallas_project.actgenerator_debatle_temp_bonus_list(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_debatle_change_code text := data.get_object_code(in_object_id);
  v_judged_person text := json.get_string(data.get_attribute_value(in_object_id, 'debatle_temp_bonus_list_person'));
begin
  assert in_actor_id is not null;

  v_actions_list := v_actions_list || 
                ', "debatle_change_bonus_back": {"code": "go_back", "name": "Вернуться к дебатлу", "disabled": false, '||
                '"params": {}}';
  v_actions_list := v_actions_list || 
                ', "debatle_change_other_bonus": {"code": "debatle_change_other_bonus", "name": "Добавить произвольный бонус", "disabled": false, '||
                 format('"params": {"debatle_change_code": "%s", "judged_person": "%s", "bonus_or_fine": "bonus"},'||
                        ' "user_params": [{"code": "bonus_reason", "description": "Описание бонуса", "type": "string", "restrictions":{"min_length": 5}},{"code": "votes", "description": "Количество прибавляемых голосов", "type": "integer", "default_value": %s }]}',
                        v_debatle_change_code,
                        v_judged_person,
                        1);
  v_actions_list := v_actions_list || 
                ', "debatle_change_other_fine": {"code": "debatle_change_other_bonus", "name": "Добавить произвольный штраф", "disabled": false, '||
                format('"params": {"debatle_change_code": "%s", "judged_person": "%s", "bonus_or_fine": "fine"},'||
                ' "user_params": [{"code": "bonus_reason", "description": "Описание штрафа", "type": "string", "restrictions":{"min_length": 5}},{"code": "votes", "description": "Количество вычитаемых голосов", "type": "integer", "default_value": %s }]}',
                v_debatle_change_code,
                v_judged_person,
                1);


  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
