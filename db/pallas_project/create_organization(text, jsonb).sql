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
  v_auditor_group_id integer := data.create_object(in_object_code || '_auditor', jsonb '{}');
  v_money jsonb := data.get_attribute_value(v_org_id, 'system_money');
  v_org_tax jsonb := data.get_attribute_value(v_org_id, 'system_org_tax');
  v_org_next_tax jsonb;
  v_org_districts_control jsonb;
  v_org_districts_influence jsonb;
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

  if v_org_tax is not null then
    v_org_next_tax := data.get_attribute_value(v_org_id, 'system_org_next_tax');
    v_org_districts_control := data.get_attribute_value(v_org_id, 'system_org_districts_control');
    v_org_districts_influence := data.get_attribute_value(v_org_id, 'system_org_districts_influence');

    perform json.get_integer(v_org_tax);
    perform json.get_integer(v_org_next_tax);
    assert json.is_string_array(v_org_districts_control);
    perform json.get_object(v_org_districts_influence);

    -- Заполняем ставки налога
    perform data.set_attribute_value(v_org_id, 'org_tax', v_org_tax, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'org_tax', v_org_tax, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'org_tax', v_org_tax, v_economist_group_id);

    perform data.set_attribute_value(v_org_id, 'org_next_tax', v_org_next_tax, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'org_next_tax', v_org_next_tax, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'org_next_tax', v_org_next_tax, v_economist_group_id);

    -- Заполняем контроль и влияние
    perform data.set_attribute_value(v_org_id, 'org_districts_control', v_org_districts_control, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'org_districts_control', v_org_districts_control, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'org_districts_control', v_org_districts_control, v_economist_group_id);

    perform data.set_attribute_value(v_org_id, 'org_districts_influence', v_org_districts_influence, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'org_districts_influence', v_org_districts_influence, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'org_districts_influence', v_org_districts_influence, v_economist_group_id);
  end if;

  perform data.set_attribute_value(v_org_id, 'org_economics_type', v_org_economics_type, v_master_group_id);

  if v_org_economics_type = jsonb '"budget"' then
    v_value := data.get_attribute_value(v_org_id, 'system_org_budget');
    perform json.get_integer(v_value);

    perform data.set_attribute_value(v_org_id, 'org_budget', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'org_budget', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'org_budget', v_value, v_economist_group_id);
  elsif v_org_economics_type = jsonb '"profit"' then
    v_value := data.get_attribute_value(v_org_id, 'system_org_profit');
    perform json.get_integer(v_value);

    perform data.set_attribute_value(v_org_id, 'org_profit', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'org_profit', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'org_profit', v_value, v_economist_group_id);
  end if;
end;
$$
language plpgsql;
