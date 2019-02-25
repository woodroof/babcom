-- drop function pallas_project.actgenerator_organization(integer, integer);

create or replace function pallas_project.actgenerator_organization(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_master boolean := pp_utils.is_in_group(in_actor_id, 'master');
  v_actor_economy_type text := json.get_string_opt(data.get_attribute_value_for_share(in_actor_id, 'system_person_economy_type'), null);
  v_actor_money bigint;
  v_is_head boolean;
  v_has_read_rights boolean;
  v_actions jsonb := jsonb '{}';
begin
  if not v_master then
    v_is_head := pp_utils.is_in_group(in_actor_id, v_object_code || '_head');
    v_has_read_rights := v_is_head or pallas_project.can_see_organization(in_actor_id, v_object_code);
  end if;

  if v_master or v_has_read_rights then
    v_actions :=
      v_actions ||
      format(
        '{
          "show_transactions": {
            "code": "act_open_object",
            "name": "Посмотреть историю транзакций",
            "disabled": false,
            "params": {
              "object_code": "%s_transactions"
            }
          }
        }',
        v_object_code)::jsonb;
  end if;

  if v_master or v_is_head then
    declare
      v_next_tax integer := json.get_integer(data.get_attribute_value(in_object_id, 'system_org_next_tax'));
    begin
      v_actions :=
        v_actions ||
        format(
          '{
            "change_next_tax": {
              "code": "change_next_tax",
              "name": "Изменить налоговую ставку на следующий цикл",
              "disabled": false,
              "params": "%s",
              "user_params": [
                {
                  "code": "tax",
                  "description": "Налог, %%",
                  "type": "integer",
                  "restrictions": {"min_value": 0, "max_value": 90},
                  "default_value": %s
                }
              ]
            }
          }',
          v_object_code,
          v_next_tax)::jsonb;
    end;
  end if;

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
      v_actions :=
        v_actions ||
        format(
          '{
            "transfer_money": {
              "code": "transfer_money",
              "name": "Перевести деньги",
              "disabled": false,
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
          v_object_code,
          v_actor_money)::jsonb;
    end if;
  end if;

  return v_actions;
end;
$$
language plpgsql;
