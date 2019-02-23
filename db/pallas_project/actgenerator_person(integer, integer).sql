-- drop function pallas_project.actgenerator_person(integer, integer);

create or replace function pallas_project.actgenerator_person(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_master boolean := pp_utils.is_in_group(in_actor_id, 'master');
  v_economy_type jsonb := data.get_attribute_value_for_share(in_object_id, 'system_person_economy_type');
  v_actor_economy_type text;
  v_actor_money bigint;
  v_tax integer;
  v_actions jsonb := jsonb '{}';
begin
  if v_master then
    if v_economy_type is not null then
      v_actions :=
        v_actions ||
        format('{
          "open_current_statuses": {
            "code": "act_open_object",
            "name": "Посмотреть текущие статусы",
            "disabled": false,
            "params": {
              "object_code": "%s_statuses"
            }
          }
        }', v_object_code)::jsonb;
      if v_economy_type != jsonb '"fixed"' then
        v_actions :=
          v_actions ||
          format('{
            "open_next_statuses": {
              "code": "act_open_object",
              "name": "Посмотреть купленные статусы на следующий цикл",
              "disabled": false,
              "params": {
                "object_code": "%s_next_statuses"
              }
            }
          }', v_object_code)::jsonb;
        if v_economy_type != jsonb '"un"' then
          v_actions :=
            v_actions ||
            format('{
              "open_transactions": {
                "code": "act_open_object",
                "name": "Посмотреть историю транзакций",
                "disabled": false,
                "params": {
                  "object_code": "%s_transactions"
                }
              }
            }', v_object_code)::jsonb;
        end if;
      end if;
    end if;
  else
    if in_object_id != in_actor_id and v_economy_type in (jsonb '"asters"', jsonb '"mcr"') then
      v_actor_economy_type := json.get_string_opt(data.get_attribute_value_for_share(in_actor_id, 'system_person_economy_type'), null);
      if v_actor_economy_type in ('asters', 'mcr') then
        v_actor_money := json.get_bigint(data.get_attribute_value_for_share(in_actor_id, 'system_money'));
        if v_actor_money <= 0 then
          v_actions :=
            v_actions ||
            jsonb '{
              "transfer_money": {
                "name": "Перевести деньги",
                "disabled": true
              }
            }';
        else
          v_tax := pallas_project.get_person_tax_for_share(in_object_id);
          v_actions :=
            v_actions ||
            format(
              '{
                "transfer_money": {
                  "code": "transfer_money",
                  "name": "Перевести деньги",
                  "warning": "С суммы перевода будет списан налог в размере %s%% с округлением вверх, продолжить?",
                  "params": "%s",
                  "user_params": [
                    {
                      "code": "sum",
                      "description": "Сумма, UN$",
                      "type": "integer",
                      "restrictions": {"min_value": 1, "max_value": %s}
                    },
                    {
                      "code": "comment",
                      "description": "Комментарий",
                      "type": "string",
                      "restrictions": {"max_length": 1000, "multiline": true}
                    }
                  ]
                }
              }',
              v_tax,
              v_object_code,
              v_actor_money)::jsonb;
        end if;
      end if;
    end if;
  end if;

  return v_actions;
end;
$$
language plpgsql;
