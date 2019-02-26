-- drop function pallas_project.actgenerator_contract(integer, integer);

create or replace function pallas_project.actgenerator_contract(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_actor_code text := data.get_object_code(in_actor_id);
  v_contract_status text := json.get_string(data.get_attribute_value_for_share(in_object_id, 'contract_status'));
  v_contract_person_code text := json.get_string(data.get_attribute_value_for_share(in_object_id, 'contract_person'));
  v_contract_org_code text := json.get_string(data.get_attribute_value_for_share(in_object_id, 'contract_org'));
  v_is_head boolean := pp_utils.is_in_group(in_actor_id, v_contract_org_code || '_head');
  v_is_economist boolean := pp_utils.is_in_group(in_actor_id, v_contract_org_code || '_economist');
  v_is_master boolean := pp_utils.is_in_group(in_actor_id, 'master');
  v_actions jsonb := '{}';
begin
  if v_contract_status not in ('not_active', 'confirmed') and v_is_master then
    v_actions :=
      v_actions ||
      format(
        '{
          "cancel_contract_immediate": {
            "code": "cancel_contract_immediate",
            "name": "Отменить контракт с ТЕКУЩЕГО цикла",
            "disabled": false,
            "warning": "Уверены? Деньги выплачены не будут, заключить можно только на следующий цикл.",
            "params": "%s"
          }
        }',
        v_object_code)::jsonb;
  end if;

  if
    v_contract_status not in ('cancelled', 'suspended_cancelled', 'not_active', 'unconfirmed') and v_contract_person_code = v_actor_code or
    v_contract_status not in ('cancelled', 'suspended_cancelled', 'not_active') and (v_is_master or v_is_head or v_is_economist)
  then
    v_actions :=
      v_actions ||
      format(
        '{
          "cancel_contract": {
            "code": "cancel_contract",
            "name": "Отменить контракт",
            "disabled": false,
            "warning": "%s",
            "params": "%s"
          }
        }',
        (case when v_contract_status = 'unconfirmed' or v_contract_status = 'confirmed' then 'Отменить контракт?' else 'Контракт будет отменён со следующего цикла. Продолжить?' end),
        v_object_code)::jsonb;
  end if;

  if v_contract_status = 'unconfirmed' then
    if v_contract_person_code = v_actor_code then
      v_actions :=
        v_actions ||
        format(
          '{
            "confirm_contract": {
              "code": "confirm_contract",
              "name": "Подтвердить",
              "disabled": false,
              "warning": "Контракт вступит в действие со следующего цикла. Продолжить?",
              "params": "%s"
            }
          }',
          v_object_code)::jsonb;
    elsif v_is_master or v_is_head or v_is_economist then
      v_actions :=
        v_actions ||
        format(
          '{
            "edit_contract": {
              "code": "edit_contract",
              "name": "Редактировать",
              "disabled": false,
              "params": "%s",
              "user_params": [
                {
                  "code": "reward",
                  "description": "Вознаграждение за цикл, UN$",
                  "type": "integer",
                  "restrictions": {"min_value": 1},
                  "default_value": %s
                },
                {
                  "code": "description",
                  "description": "Условия",
                  "type": "string",
                  "restrictions": {"min_length": 1, "max_length": 1000, "multiline": true},
                  "default_value": %s
                }
              ]
            }
          }',
          v_object_code,
          json.get_bigint(data.get_attribute_value_for_share(in_object_id, 'contract_reward')),
          data.get_attribute_value_for_share(in_object_id, 'contract_description')::text)::jsonb;
    end if;
  end if;

  if v_is_head or v_is_economist or v_is_master then
    if v_contract_status in ('active', 'cancelled') then
      v_actions :=
        v_actions ||
        format(
          '{
            "suspend_contract": {
              "code": "suspend_contract",
              "name": "Приостановить выплаты",
              "disabled": false,
              "warning": "Выплаты в конце данного цикла производиться не будут. Продолжить?",
              "params": "%s"
            }
          }',
          v_object_code)::jsonb;
    elsif v_contract_status in ('suspended', 'suspended_cancelled') then
      v_actions :=
        v_actions ||
        format(
          '{
            "unsuspend_contract": {
              "code": "unsuspend_contract",
              "name": "Возобновить выплаты",
              "disabled": false,
              "warning": "Вознаграждение по контракту будет выплачено в конце цикла. Продолжить?",
              "params": "%s"
            }
          }',
          v_object_code)::jsonb;
    end if;
  end if;

  return v_actions;
end;
$$
language plpgsql;
