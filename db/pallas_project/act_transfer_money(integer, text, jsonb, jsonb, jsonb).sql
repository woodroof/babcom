-- drop function pallas_project.act_transfer_money(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_transfer_money(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_params);
  v_object_id integer := data.get_object_id(v_object_code);
  v_original_object_code text;
  v_sum bigint := json.get_bigint(in_user_params, 'sum');
  v_comment text := pp_utils.trim(json.get_string(in_user_params, 'comment'));
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_actor_economy_type text := json.get_string(data.get_attribute_value_for_share(v_actor_id, 'system_person_economy_type'));
  v_actor_current_sum bigint := json.get_bigint(data.get_attribute_value_for_update(v_actor_id, 'system_money'));
  v_object_economy_type text;
  v_object_current_sum bigint;
  v_tax bigint;
  v_tax_organization_id integer;
  v_tax_sum bigint;
  v_tax_coeff numeric;
  v_single_diff jsonb;
  v_notified boolean;
  v_groups integer[];
begin
  v_original_object_code := json.get_string_opt(data.get_attribute_value(v_object_id, 'system_org_synonym'), null);
  if v_original_object_code is not null then
    v_object_id := data.get_object_id(v_original_object_code);
    v_object_code := v_original_object_code;
  end if;

  assert v_actor_id != v_object_id;

  v_object_economy_type := json.get_string_opt(data.get_attribute_value_for_share(v_object_id, 'system_person_economy_type'), '');
  v_object_current_sum := json.get_bigint(data.get_attribute_value_for_update(v_object_id, 'system_money'));

  if v_comment = '' then
    v_comment := 'Перевод средств';
  else
    v_comment := E'Перевод средств\nКомментарий:\n' || v_comment;
  end if;

  if v_actor_economy_type = 'un' or v_object_economy_type = 'un' then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
    return;
  end if;

  if v_actor_current_sum < v_sum then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Не хватает денег', 'На вашем счету нет указанной суммы.');
    return;
  end if;

  if v_object_economy_type != '' then
    declare
      v_district_id integer := data.get_object_id(json.get_string(data.get_attribute_value_for_share(v_object_id, 'person_district')));
      v_district_control jsonb := data.get_attribute_value_for_share(v_district_id, 'district_control');
      v_org_tax integer;
    begin
      assert v_district_control is not null;

      if v_district_control != jsonb 'null' then
        v_tax_coeff := json.get_number(data.get_attribute_value_for_share(v_district_id, 'system_district_tax_coeff'));
        v_tax_organization_id := data.get_object_id(pallas_project.control_to_org_code(json.get_string(v_district_control)));
        v_org_tax := json.get_integer(data.get_attribute_value_for_share(v_tax_organization_id, 'system_org_tax'));
        v_tax := ceil(v_org_tax * 0.01 * v_sum);
      end if;
    end;
  end if;

  v_notified :=
    data.process_diffs_and_notify_current_object(
      pallas_project.change_money(v_actor_id, v_actor_current_sum - v_sum, v_actor_id, 'Transfer'),
      in_client_id,
      in_request_id,
      v_object_id);
  -- Как минимум поменяется max_value у действия
  assert v_notified;

  perform data.process_diffs_and_notify(
    pallas_project.change_money(v_object_id, v_object_current_sum + v_sum - coalesce(v_tax, 0), v_actor_id, 'Transfer'));

  perform pallas_project.notify_transfer_sender(v_actor_id, v_sum);
  perform pallas_project.notify_transfer_receiver(v_object_id, v_sum - coalesce(v_tax, 0));

  if v_tax_organization_id is not null and v_tax != 0 then
    assert v_tax_organization_id != v_object_id;

    -- Начисление налога на следующий цикл
    v_tax_sum := json.get_bigint(data.get_attribute_value_for_update(v_tax_organization_id, 'system_org_current_tax_sum'));
    perform data.change_object_and_notify(
      v_tax_organization_id,
      format(
      '[
        {"code": "system_org_current_tax_sum", "value": %s},
        {"code": "org_current_tax_sum", "value": %s, "value_object_code": "master"}
      ]',
      v_tax_sum + (v_tax * v_tax_coeff)::bigint,
      v_tax_sum + (v_tax * v_tax_coeff)::bigint)::jsonb,
      v_actor_id,
      'Transfer tax');
  end if;

  if v_object_economy_type != '' then
    v_groups := array[v_object_id];
  else
    v_groups :=
      array[
        data.get_object_id(v_object_code || '_head'),
        data.get_object_id(v_object_code || '_economist'),
        data.get_object_id(v_object_code || '_auditor'),
        data.get_object_id(v_object_code || '_temporary_auditor')];
  end if;

  perform pallas_project.create_transaction(
    v_actor_id,
    v_comment,
    -v_sum,
    v_actor_current_sum - v_sum,
    v_tax,
    v_object_id,
    v_actor_id,
    array[v_actor_id]);
  perform pallas_project.create_transaction(
    v_object_id,
    v_comment,
    v_sum,
    v_object_current_sum + v_sum - coalesce(v_tax, 0),
    v_tax,
    v_actor_id,
    v_actor_id,
    v_groups);
end;
$$
language plpgsql;
