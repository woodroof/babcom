-- drop function pallas_project.actgenerator_contract_draft(integer, integer);

create or replace function pallas_project.actgenerator_contract_draft(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_reward bigint := json.get_bigint(data.get_attribute_value_for_share(in_object_id, 'contract_reward'));
  v_description jsonb := data.get_attribute_value_for_share(in_object_id, 'contract_description');
  v_actions jsonb := jsonb '{}';
begin
  v_actions :=
    v_actions ||
    format(
      '{
        "contract_draft_edit": {
          "code": "contract_draft_edit",
          "name": "Редактировать",
          "disabled": false,
          "params": "%s",
          "warning": "Нажмите кнопку \"Создать\", чтобы отправить контракт на подтверждение исполнителю",
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
        },
        "contract_draft_cancel": {
          "code": "contract_draft_cancel",
          "name": "👎🏻 Удалить",
          "warning": "Удалить черновик контракта?",
          "disabled": false,
          "params": "%s"
        }
      }',
      v_object_code,
      v_reward,
      v_description::text,
      v_object_code)::jsonb;

  if v_reward > 0 and v_description != '""' then
    v_actions :=
      v_actions ||
      format(
        '{
          "contract_draft_confirm": {
            "code": "contract_draft_confirm",
            "name": "👍🏻 Создать",
            "warning": "Исполнитель увидит контракт, редактирование будет доступно до принятия исполнителем контракта. Продолжить?",
            "disabled": false,
            "params": "%s"
          }
        }',
        v_object_code)::jsonb;
  else
    v_actions :=
      v_actions ||
      jsonb '{
        "contract_draft_confirm": {
          "code": "contract_draft_confirm",
          "name": "👍🏾 Создать",
          "disabled": true
        }
      }';
  end if;

  return v_actions;
end;
$$
language plpgsql;
