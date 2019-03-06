-- drop function pallas_project.act_buy_primary_resource(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_buy_primary_resource(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_resource text := json.get_string(in_params, 'resource');
  v_org_code text := json.get_string(in_params, 'org');
  v_org_id integer := data.get_object_id(v_org_code);
  v_count integer := json.get_integer(in_user_params, 'count');
  v_prices jsonb := data.get_param(v_resource || '_prices');
  v_price integer := json.get_integer(v_prices, v_org_code);
  v_sum bigint := v_price * v_count;
  v_receiver_sum bigint := floor(v_sum * 0.15);
  v_adm_id integer := data.get_object_id('org_administration');
  v_system_money_attr_id integer := data.get_attribute_id('system_money');
  v_money_attr_id integer := data.get_attribute_id('money');
  v_system_resource_attr_id integer := data.get_attribute_id('system_resource_' || v_resource);
  v_resource_attr_id integer := data.get_attribute_id('resource_' || v_resource);
  v_resource_count integer := json.get_integer(data.get_attribute_value_for_update(v_adm_id, v_system_resource_attr_id)) + v_count;
  v_current_money bigint := json.get_bigint(data.get_attribute_value_for_update(v_adm_id, v_system_money_attr_id)) - v_sum;
  v_real_object_code text := json.get_string(data.get_attribute_value(v_org_id, 'system_org_synonym'));
  v_real_object_id integer := data.get_object_id(v_real_object_code);
  v_object_current_sum bigint := json.get_bigint(data.get_attribute_value_for_update(v_real_object_id, 'system_money'));
  v_comment text :=
    format(
      E'Покупка ресурсов\nИнициатор: %s',
      pp_utils.link(v_actor_id));
  v_notified boolean;
  v_groups integer[] :=
    array[
      data.get_object_id(v_real_object_code || '_head'),
      data.get_object_id(v_real_object_code || '_economist'),
      data.get_object_id(v_real_object_code || '_auditor'),
      data.get_object_id(v_real_object_code || '_temporary_auditor')];
  v_org_groups integer[] :=
    array[
      data.get_object_id('org_administration_head'),
      data.get_object_id('org_administration_economist'),
      data.get_object_id('org_administration_auditor'),
      data.get_object_id('org_administration_temporary_auditor')];
begin
  if v_current_money < 0 then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'На счёте администрации нет нужной суммы');
    return;
  end if;

  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      v_adm_id,
      format(
        '[
          {"id": %s, "value": %s},
          {"id": %s, "value": %s, "value_object_code": "master"},
          {"id": %s, "value": %s, "value_object_code": "org_administration_head"},
          {"id": %s, "value": %s, "value_object_code": "org_administration_economist"},
          {"id": %s, "value": %s},
          {"id": %s, "value": %s, "value_object_code": "master"},
          {"id": %s, "value": %s, "value_object_code": "org_administration_head"},
          {"id": %s, "value": %s, "value_object_code": "org_administration_economist"},
          {"id": %s, "value": %s, "value_object_code": "org_administration_auditor"},
          {"id": %s, "value": %s, "value_object_code": "org_administration_temporary_auditor"}
        ]',
        v_system_resource_attr_id,
        v_resource_count,
        v_resource_attr_id,
        v_resource_count,
        v_resource_attr_id,
        v_resource_count,
        v_resource_attr_id,
        v_resource_count,
        v_system_money_attr_id,
        v_current_money,
        v_money_attr_id,
        v_current_money,
        v_money_attr_id,
        v_current_money,
        v_money_attr_id,
        v_current_money,
        v_money_attr_id,
        v_current_money,
        v_money_attr_id,
        v_current_money)::jsonb);
  assert v_notified;

  perform data.process_diffs_and_notify(
    pallas_project.change_money(v_real_object_id, v_object_current_sum + v_receiver_sum, v_actor_id, 'Transfer'));

  perform pallas_project.notify_transfer_sender(v_adm_id, v_sum);
  perform pallas_project.notify_transfer_receiver(v_real_object_id, v_receiver_sum);

  perform pallas_project.create_transaction(
    v_adm_id,
    null,
    v_comment,
    -v_sum,
    v_current_money,
    null,
    v_org_id,
    v_actor_id,
    v_org_groups);
  perform pallas_project.create_transaction(
    v_real_object_id,
    v_org_id,
    v_comment,
    v_receiver_sum,
    v_object_current_sum + v_receiver_sum,
    null,
    v_adm_id,
    v_actor_id,
    v_groups);
end;
$$
language plpgsql;
