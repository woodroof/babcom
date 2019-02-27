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
  v_district_code text;
  v_opa_rating integer;
  v_un_rating integer;
  v_actor_economy_type text;
  v_actor_money bigint;
  v_tax integer;
  v_actions jsonb := jsonb '{}';
begin
  if v_master then
    if v_economy_type is not null then
      v_district_code := json.get_string(data.get_attribute_value_for_share(in_object_id, 'person_district'));
      v_opa_rating := json.get_integer(data.get_attribute_value_for_share(in_object_id, 'person_opa_rating'));

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
          },
          "change_opa_rating": {
            "code": "change_opa_rating",
            "name": "Изменить рейтинг в СВП",
            "disabled": false,
            "params": "%s",
            "user_params": [
              {
                "code": "opa_rating_diff",
                "description": "Значение изменения рейтинга (сейчас %s)",
                "type": "integer",
                "restrictions": {"min_value": %s},
                "default_value": 1
              },
              {
                "code": "comment",
                "description": "Причина изменения",
                "type": "string",
                "restrictions": {"min_length": 1, "max_length": 1000, "multiline": true}
              }
            ]
          },
          "change_district": {
            "code": "change_district",
            "name": "Изменить сектор проживания",
            "disabled": false,
            "params": "%s",
            "user_params": [
              {
                "code": "district_letter",
                "description": "Буква нового сектора",
                "type": "string",
                "restrictions": {"min_length": 1, "max_length": 1},
                "default_value": "%s"
              },
              {
                "code": "comment",
                "description": "Причина изменения",
                "type": "string",
                "restrictions": {"min_length": 1, "max_length": 1000, "multiline": true}
              }
            ]
          }
        }',
        v_object_code,
        v_object_code,
        v_opa_rating,
        -v_opa_rating + 1,
        v_object_code,
        substring(v_district_code from length(v_district_code)))::jsonb;

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
            },
            "open_contracts": {
              "code": "act_open_object",
              "name": "Посмотреть контракты",
              "disabled": false,
              "params": {
                "object_code": "%s_contracts"
              }
            }
          }',
          v_object_code,
          v_object_code)::jsonb;

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
        else
          v_un_rating := json.get_integer(data.get_attribute_value_for_share(in_object_id, 'person_un_rating'));

          v_actions :=
            v_actions ||
            format('{
              "change_un_rating": {
                "code": "change_un_rating",
                "name": "Изменить рейтинг гражданина",
                "disabled": false,
                "params": "%s",
                "user_params": [
                  {
                    "code": "un_rating_diff",
                    "description": "Значение изменения рейтинга (сейчас %s)",
                    "type": "integer"
                  },
                  {
                    "code": "comment",
                    "description": "Причина изменения",
                    "type": "string",
                    "restrictions": {"min_length": 1, "max_length": 1000, "multiline": true}
                  }
                ]
              }
            }',
            v_object_code,
            v_un_rating)::jsonb;
        end if;
      end if;
    end if;
    v_actions :=
            v_actions ||
            format('{
              "med_health": {
                "code": "act_open_object",
                "name": "Добавить болезней",
                "disabled": false,
                "params": {
                  "object_code": "%s_med_health"
                }
              }
            }', v_object_code)::jsonb;
  else
    if v_economy_type in (jsonb '"asters"', jsonb '"mcr"') then
      v_tax := pallas_project.get_person_tax_for_share(in_object_id);

      if in_object_id != in_actor_id then
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

      declare
        v_actor_code text := data.get_object_code(in_actor_id);
        v_my_organizations jsonb;
        v_title_attr_id integer;
        v_my_organization record;
      begin
        if data.is_object_exists(v_actor_code || '_my_organizations') then
          v_my_organizations := data.get_raw_attribute_value_for_share(data.get_object_id(v_actor_code || '_my_organizations'), 'content');

          if v_my_organizations != '[]' then
            v_title_attr_id := data.get_attribute_id('title');

            for v_my_organization in
            (
              select row_number() over() as num, code, title
              from (
                select o.code, json.get_string(data.get_attribute_value(o.id, v_title_attr_id)) title
                from jsonb_array_elements(v_my_organizations) m
                join data.objects o on
                  o.code = json.get_string(m.value) and
                  (pp_utils.is_in_group(in_actor_id, o.code || '_head') or pp_utils.is_in_group(in_actor_id, o.code || '_economist'))
                order by title
                limit 5) orgs
            )
            loop
              v_actions :=
                v_actions ||
                format(
                  '{
                    "transfer_org_money%s": {
                      "code": "transfer_org_money",
                      "name": "Перевести деньги от лица организации %s",
                      "warning": "С суммы перевода будет списан налог в размере %s%% с округлением вверх, продолжить?",
                      "disabled": false,
                      "params": {
                        "org_code": "%s",
                        "receiver_code": "%s"
                      },
                      "user_params": [
                        {
                          "code": "sum",
                          "description": "Сумма, UN$",
                          "type": "integer",
                          "restrictions": {"min_value": 1}
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
                  v_my_organization.num,
                  v_my_organization.title,
                  v_tax,
                  v_my_organization.code,
                  v_object_code)::jsonb;
            end loop;
          end if;
        end if;
      end;
    end if;
  end if;

  return v_actions;
end;
$$
language plpgsql;
