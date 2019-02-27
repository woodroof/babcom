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

    if v_master then
      declare
        v_tax integer := json.get_integer(data.get_attribute_value(in_object_id, 'system_org_tax'));
      begin
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
      end;
    end if;
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
        end loop;
      end if;
    end if;
  end;

  return v_actions;
end;
$$
language plpgsql;
