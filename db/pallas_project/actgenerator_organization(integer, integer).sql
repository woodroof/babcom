-- drop function pallas_project.actgenerator_organization(integer, integer);

create or replace function pallas_project.actgenerator_organization(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_master boolean := pp_utils.is_in_group(in_actor_id, 'master');
  v_is_real_org boolean := data.is_object_exists(v_object_code || '_head');
  v_actor_economy_type text := json.get_string_opt(data.get_attribute_value_for_share(in_actor_id, 'system_person_economy_type'), null);
  v_actor_money bigint;
  v_is_head boolean;
  v_is_economist boolean;
  v_is_auditor boolean;
  v_actions jsonb := jsonb '{}';
begin
  if not v_master and v_is_real_org then
    v_is_head := pp_utils.is_in_group(in_actor_id, v_object_code || '_head');
    v_is_economist := pp_utils.is_in_group(in_actor_id, v_object_code || '_economist');
    if not v_is_head and not v_is_economist then
      v_is_auditor :=
        pp_utils.is_in_group(in_actor_id, v_object_code || '_auditor') or
        pp_utils.is_in_group(in_actor_id, v_object_code || '_temporary_auditor');
    end if;
  end if;

  if v_master or v_is_head then
    v_actions :=
      v_actions ||
      format(
        '{
          "show_claims": {
            "code": "act_open_object",
            "name": "Посмотреть список исков",
            "disabled": false,
            "params": {
              "object_code": "%s_claims"
            }
          }
        }',
        v_object_code)::jsonb;
  end if;

  if v_is_real_org then
    if v_object_code = 'org_administration' then
      if v_is_economist then
        declare
          v_primary_resource text;
          v_org record;
          v_prices jsonb;
        begin
          for v_primary_resource in
          (
            select *
            from unnest(array['ice', 'foodstuff', 'medical_supplies', 'uranium', 'methane', 'goods'])
          )
          loop
            v_prices := data.get_param(v_primary_resource || '_prices');
            for v_org in
            (
              select key, json.get_integer(value) as value
              from jsonb_each(v_prices)
            )
            loop
              v_actions :=
                v_actions ||
                format(
                  '{
                    "buy_%s": {
                      "code": "act_buy_primary_resource",
                      "name": "Купить у %s (%s)",
                      "disabled": false,
                      "params": {
                        "resource": "%s",
                        "org": "%s"
                      },
                      "user_params": [
                        {
                          "code": "count",
                          "description": "Количество",
                          "type": "integer",
                          "restrictions": {"min_value": 1}
                        }
                      ]
                    }
                  }',
                  substring(v_org.key from 5),
                  json.get_string(data.get_attribute_value(v_org.key, 'title')),
                  pp_utils.format_money(v_org.value),
                  v_primary_resource,
                  v_org.key)::jsonb;
            end loop;
          end loop;
        end;
      end if;

      if pp_utils.is_in_group(in_actor_id, 'org_administration_ecologist') then
        declare
          v_resource text;
          v_org record;
        begin
          for v_resource in
          (
            select *
            from unnest(array['water', 'food', 'medicine', 'power', 'fuel', 'spare_parts'])
          )
          loop
            v_actions :=
              v_actions ||
              format(
                '{
                  "produce_%s": {
                    "code": "act_produce_resource",
                    "name": "Произвести",
                    "disabled": false,
                    "params": {
                      "resource": "%s"
                    },
                    "user_params": [
                      {
                        "code": "count",
                        "description": "Количество",
                        "type": "integer",
                        "restrictions": {"min_value": 1}
                      }
                    ]
                  }
                }',
                v_resource,
                v_resource)::jsonb;
          end loop;
        end;
      end if;
    end if;

    if v_master or v_is_head or v_is_economist or v_is_auditor then
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
            },
            "show_contracts": {
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
    end if;

    if v_master or v_is_head then
      declare
        v_next_tax integer := json.get_integer_opt(data.get_raw_attribute_value_for_share(in_object_id, 'system_org_next_tax'), null);
      begin
        if v_next_tax is not null then
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
        end if;
      end;
    end if;

    if v_master then
      declare
        v_tax integer := json.get_integer_opt(data.get_raw_attribute_value_for_share(in_object_id, 'system_org_tax'), null);
        v_budget integer := json.get_integer_opt(data.get_raw_attribute_value_for_share(in_object_id, 'system_org_budget'), null);
        v_profit integer := json.get_integer_opt(data.get_raw_attribute_value_for_share(in_object_id, 'system_org_profit'), null);
        v_money integer := json.get_integer(data.get_raw_attribute_value_for_share(in_object_id, 'system_money'));
      begin
        if v_tax is not null then
          v_actions :=
            v_actions ||
            format(
              '{
                "change_current_tax": {
                  "code": "change_current_tax",
                  "name": "Изменить налоговую ставку на ТЕКУЩИЙ цикл",
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
              v_tax)::jsonb;
        end if;

        if v_budget is not null then
          v_actions :=
            v_actions ||
            format(
              '{
                "change_next_budget": {
                  "code": "change_next_budget",
                  "name": "Изменить бюджет на следующий цикл",
                  "disabled": false,
                  "params": "%s",
                  "user_params": [
                    {
                      "code": "budget",
                      "description": "Бюджет на следующий цикл, UN$",
                      "type": "integer",
                      "restrictions": {"min_value": 0},
                      "default_value": %s
                    }
                  ]
                }
              }',
              v_object_code,
              v_budget)::jsonb;
        end if;

        if v_profit is not null then
          v_actions :=
            v_actions ||
            format(
              '{
                "change_next_profit": {
                  "code": "change_next_profit",
                  "name": "Изменить доход на следующий цикл",
                  "disabled": false,
                  "params": "%s",
                  "user_params": [
                    {
                      "code": "profit",
                      "description": "Доход на следующий цикл, UN$",
                      "type": "integer",
                      "restrictions": {"min_value": 0},
                      "default_value": %s
                    }
                  ]
                }
              }',
              v_object_code,
              v_profit)::jsonb;
        end if;

        v_actions :=
          v_actions ||
          format('{
            "change_org_money": {
              "code": "change_org_money",
              "name": "Изменить количество денег на счёте",
              "disabled": false,
              "params": "%s",
              "user_params": [
                {
                  "code": "money_diff",
                  "description": "Значение изменения остатка, UN$ (сейчас %s)",
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
          v_money)::jsonb;
      end;
    end if;
  end if;

  if v_actor_economy_type in ('asters', 'mcr', 'fixed_with_money') then
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
              o.id != in_object_id and
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
              v_my_organization.code,
              v_object_code)::jsonb;

          if
            v_object_code in ('org_administration', 'org_star_helix', 'org_clinic', 'org_akira_sc', 'org_teco_mars', 'org_de_beers') and
            v_my_organization.code in ('org_administration', 'org_star_helix', 'org_clinic', 'org_akira_sc', 'org_teco_mars', 'org_de_beers')
          then
            declare
              v_resource text;
            begin
              for v_resource in
              (
                select *
                from unnest(array['water', 'power', 'fuel', 'spare_parts'])
              )
              loop
                v_actions :=
                  v_actions ||
                  format(
                    '{
                      "transfer_org_%s%s": {
                        "code": "transfer_org_resource",
                        "name": "Передать %s из запасов организации %s",
                        "disabled": false,
                        "params": {
                          "org_code": "%s",
                          "receiver_code": "%s",
                          "resource": "%s"
                        },
                        "user_params": [
                          {
                            "code": "count",
                            "description": "Количество",
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
                    v_resource,
                    v_my_organization.num,
                    pallas_project.resource_to_text_r(v_resource),
                    v_my_organization.title,
                    v_my_organization.code,
                    v_object_code,
                    v_resource)::jsonb;
              end loop;
            end;
          end if;
        end loop;
      end if;
    end if;
  end;

  return v_actions;
end;
$$
language plpgsql;
