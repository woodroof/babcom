-- drop function pallas_project.create_organization(text, jsonb);

create or replace function pallas_project.create_organization(in_object_code text, in_attributes jsonb)
returns void
volatile
as
$$
-- Не для использования на игре, т.к. обновляет атрибуты напрямую, без уведомлений и блокировок!
declare
  v_master_group_id integer := data.get_object_id('master');
  v_org_id integer := data.create_object(in_object_code, in_attributes, 'organization');
  v_head_group_id integer := data.create_object(in_object_code || '_head', jsonb '{}');
  v_economist_group_id integer := data.create_object(in_object_code || '_economist', jsonb '{}');
  v_ecologist_group_id integer;
  v_auditor_group_id integer := data.create_object(in_object_code || '_auditor', jsonb '{}');
  v_temporary_auditor_group_id integer := data.create_object(in_object_code || '_temporary_auditor', jsonb '{}');
  v_money jsonb := data.get_attribute_value(v_org_id, 'system_money');
  v_org_tax jsonb := data.get_attribute_value(v_org_id, 'system_org_tax');
  v_org_next_tax jsonb;
  v_org_current_tax_sum jsonb;
  v_org_economics_type jsonb := data.get_attribute_value(v_org_id, 'system_org_economics_type');
  v_value jsonb;
begin
  perform json.get_bigint(v_money);
  assert json.get_string(v_org_economics_type) in ('normal', 'budget', 'profit');

  -- Перекладываем деньги
  perform data.set_attribute_value(v_org_id, 'money', v_money, v_master_group_id);
  perform data.set_attribute_value(v_org_id, 'money', v_money, v_head_group_id);
  perform data.set_attribute_value(v_org_id, 'money', v_money, v_economist_group_id);
  perform data.set_attribute_value(v_org_id, 'money', v_money, v_auditor_group_id);
  perform data.set_attribute_value(v_org_id, 'money', v_money, v_temporary_auditor_group_id);

  if v_org_tax is not null then
    v_org_next_tax := data.get_attribute_value(v_org_id, 'system_org_next_tax');
    v_org_current_tax_sum := data.get_attribute_value(v_org_id, 'system_org_current_tax_sum');

    perform json.get_integer(v_org_tax);
    perform json.get_integer(v_org_next_tax);
    perform json.get_bigint(v_org_current_tax_sum);

    -- Заполняем ставки налога
    perform data.set_attribute_value(v_org_id, 'org_tax', v_org_tax, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'org_tax', v_org_tax, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'org_tax', v_org_tax, v_economist_group_id);

    perform data.set_attribute_value(v_org_id, 'org_next_tax', v_org_next_tax, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'org_next_tax', v_org_next_tax, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'org_next_tax', v_org_next_tax, v_economist_group_id);

    -- Заполняем контроль и влияние
    perform pallas_project.update_org_districts_control(v_org_id);
    perform pallas_project.update_org_districts_influence(v_org_id);

    -- Заполняем накопленные налоги
    perform data.set_attribute_value(v_org_id, 'org_current_tax_sum', v_org_current_tax_sum, v_master_group_id);
  end if;

  perform data.set_attribute_value(v_org_id, 'org_economics_type', v_org_economics_type, v_master_group_id);

  if v_org_economics_type = jsonb '"budget"' then
    v_value := data.get_attribute_value(v_org_id, 'system_org_budget');
    perform json.get_integer(v_value);

    perform data.set_attribute_value(v_org_id, 'org_budget', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'org_budget', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'org_budget', v_value, v_economist_group_id);

    perform data.add_object_to_object(v_org_id, 'budget_orgs');
  elsif v_org_economics_type = jsonb '"profit"' then
    v_value := data.get_attribute_value(v_org_id, 'system_org_profit');
    perform json.get_integer(v_value);

    perform data.set_attribute_value(v_org_id, 'org_profit', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'org_profit', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'org_profit', v_value, v_economist_group_id);

    perform data.add_object_to_object(v_org_id, 'profit_orgs');
  end if;

  if in_object_code = 'org_administration' then
    v_ecologist_group_id := data.get_object_id('org_administration_ecologist');

    v_value := data.get_attribute_value(v_org_id, 'system_resource_ice');
    perform data.set_attribute_value(v_org_id, 'resource_ice', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_ice', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_ice', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_ice', v_value, v_ecologist_group_id);
    v_value := data.get_attribute_value(v_org_id, 'system_resource_foodstuff');
    perform data.set_attribute_value(v_org_id, 'resource_foodstuff', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_foodstuff', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_foodstuff', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_foodstuff', v_value, v_ecologist_group_id);
    v_value := data.get_attribute_value(v_org_id, 'system_resource_medical_supplies');
    perform data.set_attribute_value(v_org_id, 'resource_medical_supplies', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_medical_supplies', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_medical_supplies', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_medical_supplies', v_value, v_ecologist_group_id);
    v_value := data.get_attribute_value(v_org_id, 'system_resource_uranium');
    perform data.set_attribute_value(v_org_id, 'resource_uranium', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_uranium', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_uranium', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_uranium', v_value, v_ecologist_group_id);
    v_value := data.get_attribute_value(v_org_id, 'system_resource_methane');
    perform data.set_attribute_value(v_org_id, 'resource_methane', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_methane', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_methane', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_methane', v_value, v_ecologist_group_id);
    v_value := data.get_attribute_value(v_org_id, 'system_resource_goods');
    perform data.set_attribute_value(v_org_id, 'resource_goods', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_goods', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_goods', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_goods', v_value, v_ecologist_group_id);

    v_value := data.get_attribute_value(v_org_id, 'system_ice_efficiency');
    perform data.set_attribute_value(v_org_id, 'ice_efficiency', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'ice_efficiency', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'ice_efficiency', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'ice_efficiency', v_value, v_ecologist_group_id);
    v_value := data.get_attribute_value(v_org_id, 'system_foodstuff_efficiency');
    perform data.set_attribute_value(v_org_id, 'foodstuff_efficiency', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'foodstuff_efficiency', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'foodstuff_efficiency', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'foodstuff_efficiency', v_value, v_ecologist_group_id);
    v_value := data.get_attribute_value(v_org_id, 'system_medical_supplies_efficiency');
    perform data.set_attribute_value(v_org_id, 'medical_supplies_efficiency', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'medical_supplies_efficiency', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'medical_supplies_efficiency', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'medical_supplies_efficiency', v_value, v_ecologist_group_id);
    v_value := data.get_attribute_value(v_org_id, 'system_uranium_efficiency');
    perform data.set_attribute_value(v_org_id, 'uranium_efficiency', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'uranium_efficiency', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'uranium_efficiency', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'uranium_efficiency', v_value, v_ecologist_group_id);
    v_value := data.get_attribute_value(v_org_id, 'system_methane_efficiency');
    perform data.set_attribute_value(v_org_id, 'methane_efficiency', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'methane_efficiency', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'methane_efficiency', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'methane_efficiency', v_value, v_ecologist_group_id);
    v_value := data.get_attribute_value(v_org_id, 'system_goods_efficiency');
    perform data.set_attribute_value(v_org_id, 'goods_efficiency', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'goods_efficiency', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'goods_efficiency', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'goods_efficiency', v_value, v_ecologist_group_id);

    v_value := data.get_attribute_value(v_org_id, 'system_resource_water');
    perform data.set_attribute_value(v_org_id, 'resource_water', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_water', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_water', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_water', v_value, v_ecologist_group_id);
    v_value := data.get_attribute_value(v_org_id, 'system_resource_food');
    perform data.set_attribute_value(v_org_id, 'resource_food', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_food', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_food', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_food', v_value, v_ecologist_group_id);
    v_value := data.get_attribute_value(v_org_id, 'system_resource_medicine');
    perform data.set_attribute_value(v_org_id, 'resource_medicine', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_medicine', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_medicine', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_medicine', v_value, v_ecologist_group_id);
    v_value := data.get_attribute_value(v_org_id, 'system_resource_power');
    perform data.set_attribute_value(v_org_id, 'resource_power', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_power', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_power', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_power', v_value, v_ecologist_group_id);
    v_value := data.get_attribute_value(v_org_id, 'system_resource_fuel');
    perform data.set_attribute_value(v_org_id, 'resource_fuel', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_fuel', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_fuel', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_fuel', v_value, v_ecologist_group_id);
    v_value := data.get_attribute_value(v_org_id, 'system_resource_spare_parts');
    perform data.set_attribute_value(v_org_id, 'resource_spare_parts', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_spare_parts', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_spare_parts', v_value, v_economist_group_id);
    perform data.set_attribute_value(v_org_id, 'resource_spare_parts', v_value, v_ecologist_group_id);
  else
    v_value := data.get_attribute_value(v_org_id, 'system_resource_water');
    if v_value is not null then
      perform data.set_attribute_value(v_org_id, 'resource_water', v_value, v_master_group_id);
      perform data.set_attribute_value(v_org_id, 'resource_water', v_value, v_head_group_id);
    end if;
    v_value := data.get_attribute_value(v_org_id, 'system_resource_food');
    if v_value is not null then
      perform data.set_attribute_value(v_org_id, 'resource_food', v_value, v_master_group_id);
      perform data.set_attribute_value(v_org_id, 'resource_food', v_value, v_head_group_id);
    end if;
    v_value := data.get_attribute_value(v_org_id, 'system_resource_medicine');
    if v_value is not null then
      perform data.set_attribute_value(v_org_id, 'resource_medicine', v_value, v_master_group_id);
      perform data.set_attribute_value(v_org_id, 'resource_medicine', v_value, v_head_group_id);
    end if;
    v_value := data.get_attribute_value(v_org_id, 'system_resource_power');
    if v_value is not null then
      perform data.set_attribute_value(v_org_id, 'resource_power', v_value, v_master_group_id);
      perform data.set_attribute_value(v_org_id, 'resource_power', v_value, v_head_group_id);
    end if;
    v_value := data.get_attribute_value(v_org_id, 'system_resource_fuel');
    if v_value is not null then
      perform data.set_attribute_value(v_org_id, 'resource_fuel', v_value, v_master_group_id);
      perform data.set_attribute_value(v_org_id, 'resource_fuel', v_value, v_head_group_id);
    end if;
    v_value := data.get_attribute_value(v_org_id, 'system_resource_spare_parts');
    if v_value is not null then
      perform data.set_attribute_value(v_org_id, 'resource_spare_parts', v_value, v_master_group_id);
      perform data.set_attribute_value(v_org_id, 'resource_spare_parts', v_value, v_head_group_id);
    end if;

    v_value := data.get_attribute_value(v_org_id, 'system_resource_ore');
    if v_value is not null then
      perform data.set_attribute_value(v_org_id, 'resource_ore', v_value, v_master_group_id);
      perform data.set_attribute_value(v_org_id, 'resource_ore', v_value, v_head_group_id);
    end if;
    v_value := data.get_attribute_value(v_org_id, 'system_resource_iridium');
    if v_value is not null then
      perform data.set_attribute_value(v_org_id, 'resource_iridium', v_value, v_master_group_id);
      perform data.set_attribute_value(v_org_id, 'resource_iridium', v_value, v_head_group_id);
    end if;
    v_value := data.get_attribute_value(v_org_id, 'system_resource_diamonds');
    if v_value is not null then
      perform data.set_attribute_value(v_org_id, 'resource_diamonds', v_value, v_master_group_id);
      perform data.set_attribute_value(v_org_id, 'resource_diamonds', v_value, v_head_group_id);
    end if;
  end if;

  -- Создадим страницу с историей транзакций
  perform data.create_object(
    in_object_code || '_transactions',
    format(
      '[
        {"code": "title", "value": "%s"},
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "content", "value": []}
      ]',
      format('История транзакций, %s', json.get_string(data.get_attribute_value(v_org_id, 'title'))),
      v_head_group_id,
      v_economist_group_id,
      v_auditor_group_id,
      v_temporary_auditor_group_id,
      v_master_group_id)::jsonb,
    'transactions');

  -- Список исков
  perform data.create_object(
    in_object_code || '_claims',
    format(
      '[
        {"code": "title", "value": "%s"},
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "content", "value": []}
      ]',
      format('Список исков, %s', json.get_string(data.get_attribute_value(v_org_id, 'title'))),
      v_head_group_id,
      v_master_group_id)::jsonb,
    'claim_list');

  -- Создадим список контактов
  perform data.create_object(
    in_object_code || '_contracts',
    format(
      '[
        {"code": "title", "value": "Контракты, %s"},
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "content", "value": []}
      ]',
      json.get_string(data.get_attribute_value(v_org_id, 'title')),
      v_head_group_id,
      v_economist_group_id,
      v_auditor_group_id,
      v_temporary_auditor_group_id)::jsonb,
    'contract_list');
end;
$$
language plpgsql;
