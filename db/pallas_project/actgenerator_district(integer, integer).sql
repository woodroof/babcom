-- drop function pallas_project.actgenerator_district(integer, integer);

create or replace function pallas_project.actgenerator_district(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_is_master boolean := pp_utils.is_in_group(in_actor_id, 'master');
  v_object_code text;
  v_district_control text;
  v_district_influence jsonb;
  v_adm_influence integer;
  v_opa_influence integer;
  v_cartel_influence integer;
  v_control_code text;
  v_control_org_name_r text;
  v_control_org_name_d text;
  v_actions jsonb := jsonb '{}';
begin
  if v_is_master then
    v_object_code := data.get_object_code(in_object_id);
    v_district_control := json.get_string_opt(data.get_attribute_value_for_share(in_object_id, 'district_control'), '');
    v_district_influence := data.get_attribute_value_for_share(in_object_id, 'district_influence');

    v_adm_influence := json.get_integer(v_district_influence, 'administration');
    v_opa_influence := json.get_integer(v_district_influence, 'opa');
    v_cartel_influence := json.get_integer(v_district_influence, 'cartel');

    v_actions :=
      v_actions ||
      format(
        '{
          "change_administration_influence": {
            "code": "district_change_influence",
            "name": "Изменить влияние администрации",
            "disabled": false,
            "params": {
              "object_code": "%s",
              "control_code": "administration"
            },
            "warning": "Причина будет указана в уведомлении руководству организации. Продолжить?",
            "user_params": [
              {
                "code": "influence_diff",
                "description": "Значение изменения влияния (текущее значение: %s)",
                "type": "integer",
                "restrictions": {"min_value": %s}
              },
              {
                "code": "description",
                "description": "Причина изменения",
                "type": "string",
                "restrictions": {"min_length": 1, "multiline": true}
              }
            ]
          },
          "change_opa_influence": {
            "code": "district_change_influence",
            "name": "Изменить влияние СВП",
            "disabled": false,
            "params": {
              "object_code": "%s",
              "control_code": "opa"
            },
            "warning": "Причина будет указана в уведомлении руководству организации. Продолжить?",
            "user_params": [
              {
                "code": "influence_diff",
                "description": "Значение изменения влияния (текущее значение: %s)",
                "type": "integer",
                "restrictions": {"min_value": %s}
              },
              {
                "code": "description",
                "description": "Причина изменения",
                "type": "string",
                "restrictions": {"min_length": 1, "multiline": true}
              }
            ]
          },
          "change_cartel_influence": {
            "code": "district_change_influence",
            "name": "Изменить влияние картеля",
            "disabled": false,
            "params": {
              "object_code": "%s",
              "control_code": "cartel"
            },
            "warning": "Причина будет указана в уведомлении руководству организации. Продолжить?",
            "user_params": [
              {
                "code": "influence_diff",
                "description": "Значение изменения влияния (текущее значение: %s)",
                "type": "integer",
                "restrictions": {"min_value": %s}
              },
              {
                "code": "description",
                "description": "Причина изменения",
                "type": "string",
                "restrictions": {"min_length": 1, "multiline": true}
              }
            ]
          }
        }',
        v_object_code,
        v_adm_influence,
        -v_adm_influence,
        v_object_code,
        v_opa_influence,
        -v_opa_influence,
        v_object_code,
        v_cartel_influence,
        -v_cartel_influence)::jsonb;

    for v_control_code in
    (
      select value
      from unnest(array['administration', 'opa', 'cartel']) a(value)
    )
    loop
      v_control_org_name_r := (case when v_control_code = 'administration' then 'администрации' when v_control_code = 'opa' then 'СВП' else 'картеля' end);
      v_control_org_name_d := (case when v_control_code = 'administration' then 'администрации' when v_control_code = 'opa' then 'СВП' else 'картелю' end);

      if v_district_control = v_control_code then
        v_actions :=
          v_actions ||
          format('
            {
              "set_%s_control": {
                "code": "district_change_control",
                "name": "Установить контроль %s",
                "disabled": true
              }
            }',
            v_control_code,
            v_control_org_name_r)::jsonb;
      else
        v_actions :=
          v_actions ||
          format('
            {
              "set_%s_control": {
                "code": "district_change_control",
                "name": "Установить контроль %s",
                "disabled": false,
                "warning": "Влияние %s будет установлено в 1, влияние остальных - в 0. Контроль будет передан %s. Продолжить?",
                "params": {
                  "object_code": "%s",
                  "control_code": "%s"
                }
              }
            }',
            v_control_code,
            v_control_org_name_r,
            v_control_org_name_r,
            v_control_org_name_d,
            v_object_code,
            v_control_code)::jsonb;
      end if;
    end loop;

    if v_district_control != '' then
      v_actions :=
        v_actions ||
        format(
          '{
            "remove_control": {
              "code": "district_remove_control",
              "name": "Убрать контроль",
              "disabled": false,
              "warning": "Будет только убран контроль, влияние организаций не поменяется. Причина будет указана в уведомлении руководству организации. Продолжить?",
              "params": {
                "object_code": "%s",
                "control_code": "%s"
              },
              "user_params": [
                {
                  "code": "description",
                  "description": "Причина изменения",
                  "type": "string",
                  "restrictions": {"min_length": 1, "multiline": true}
                }
              ]
            }
          }',
          v_object_code,
          v_district_control)::jsonb;
    end if;
  end if;

  return v_actions;
end;
$$
language plpgsql;
