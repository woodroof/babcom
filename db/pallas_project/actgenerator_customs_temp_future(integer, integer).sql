-- drop function pallas_project.actgenerator_customs_temp_future(integer, integer);

create or replace function pallas_project.actgenerator_customs_temp_future(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_package_to text := json.get_string_opt(data.get_raw_attribute_value_for_share(in_object_id, 'package_to', null), null);
  v_package_reactions jsonb := coalesce(data.get_raw_attribute_value_for_share(in_object_id, 'package_reactions'), jsonb '[]');
begin
  assert in_actor_id is not null;

  v_actions_list := v_actions_list || 
                ', "customs_future_back": {"code": "go_back", "name": "Отмена", "disabled": false, '||
                '"params": {}}';
  v_actions_list := v_actions_list || 
              format(', "customs_temp_future_create": {"code": "customs_temp_future_create", "name": "Создать посылку", "disabled": false,'||
                '"params": {"package_to": "%s", "package_reactions": %s}, 
                 "user_params": [{"code": "ships_count", "description": "Порядковый номер корабля, в котором должно прилететь (1, если в следующем)", "type": "integer", "default_value": 1},
                                 {"code": "package_from", "description": "Название планеты, спутника или астероида, с которого груз (русскими с заглавной)", "type": "string"},
                                 {"code": "package_box", "description": "Код или номер картонной коробки", "type": "string"}]}',
                v_package_to,
                jsonb_pretty(v_package_reactions));

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
