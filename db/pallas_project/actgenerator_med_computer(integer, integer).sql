-- drop function pallas_project.actgenerator_med_computer(integer, integer);

create or replace function pallas_project.actgenerator_med_computer(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_is_master boolean;
  v_medcomputer_code text := data.get_object_code(in_object_id);
  v_person_code text := json.get_string(data.get_attribute_value_for_share(in_object_id, 'med_person_code'));
  v_med_health jsonb := data.get_attribute_value_for_share(in_object_id, 'med_health');
  v_level integer;
  v_disease_params jsonb;
  v_time_to_next integer;
  v_next_level integer;
  v_disease text;
begin
  assert in_actor_id is not null;

  for v_disease in (select * from unnest(array['wound', 'radiation', 'asthma', 'rio_miamore', 'addiction', 'genetic', 'sleg', 'sleg_addiction', 'back_rio_miamore'])) loop
    select x.level into v_level
    from jsonb_to_record(jsonb_extract_path(v_med_health, v_disease)) as x(level integer);
    v_disease_params := data.get_param('med_' || v_disease );

    if coalesce(v_level, 0) <> 0 then
      select x.time, coalesce(x.next_level, v_level + 1) into v_time_to_next, v_next_level
      from jsonb_to_record(jsonb_extract_path(v_disease_params, 'l' || v_level)) as x(time integer, next_level integer);

      v_actions_list := v_actions_list || 
            format(', "med_diagnose_%s": {"code": "med_set_disease_level", "name": "%s", "disabled": false,'||
                    '"params": {"med_computer_code": "%s", "person_code": "%s", "disease": "%s", "level": %s}, 
                    "user_params": [{"code": "diagnosted", "description": "diagnosted", "type": "integer"}]}',
                    v_disease,
                    v_disease,
                    v_medcomputer_code,
                    v_person_code,
                    v_disease,
                    case when v_time_to_next is not null then v_next_level else v_level end);
    end if;
  end loop;

  v_actions_list := v_actions_list || 
        format(', "med_cure": {"code": "med_cure", "name": "med_cure", "disabled": false,'||
                '"params": {"med_computer_code": "%s", "person_code": "%s"},
                "user_params": [{"code": "disease", "description": "disease", "type": "string"}, 
                                {"code": "level", "description": "level", "type": "integer"},
                                {"code": "message", "description": "Сообщение для пациента", "type": "string"},
                                {"code": "med_clinic_money_price", "description": "Стоимость лечения в деньгах", "type": "integer"},
                                {"code": "med_clinic_panacelin_price", "description": "Стоимость лечения в панацелине", "type": "integer"}]}',
                v_medcomputer_code,
                v_person_code);

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
