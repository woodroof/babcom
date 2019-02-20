-- drop function pallas_project.act_buy_status(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_buy_status(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_status_name text := json.get_string(in_params, 'status_name');
  v_status_value integer := json.get_integer(in_params, 'value');
  v_status_attribute_id integer = data.get_attribute_id('system_person_next_' || v_status_name || '_status');
  v_economy_type text := json.get_string(data.get_attribute_value_for_share(v_actor_id, 'system_person_economy_type'));
  v_currency_attribute_id integer = data.get_attribute_id(case when v_economy_type = 'un' then 'system_person_coin' else 'system_money' end);
  v_status_prices integer[] := data.get_integer_array_param(v_status_name || '_status_prices');
  v_current_status_value integer := json.get_integer(data.get_attribute_value_for_update(v_actor_id, v_status_attribute_id));
  v_current_sum bigint := json.get_bigint(data.get_attribute_value_for_update(v_actor_id, v_currency_attribute_id));
  v_price bigint;
  v_diff jsonb;
  v_notified boolean;
begin
  assert in_request_id is not null;
  assert in_user_params is null;
  assert in_default_params is null;

  select sum(v_status_prices[value])
  into v_price
  from unnest(array[1, 2, 3]) a(value)
  where
    value > v_current_status_value and
    value <= v_status_value;

  if v_economy_type != 'un' then
    v_price := v_price * data.get_integer_param('coin_price');
  end if;

  if v_current_status_value >= v_status_value or v_price > v_current_sum then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
    return;
  end if;

  if v_economy_type = 'un' then
    v_diff := pallas_project.change_coins(v_actor_id, (v_current_sum - v_price)::integer, v_actor_id, 'Status purchase');
  else
    v_diff := pallas_project.change_person_money(v_actor_id, v_current_sum - v_price, v_actor_id, 'Status purchase');
    perform pallas_project.create_transaction(
      v_actor_id,
      format(
        'Покупка %s статуса "%s"',
        (case when v_status_value = 1 then 'бронзового' when v_status_value = 2 then 'серебряного' else 'золотого' end),
        json.get_string(data.get_raw_attribute_value(data.get_class_id(v_status_name || '_status_page'), 'title'))),
      -v_price,
      v_current_sum - v_price,
      null,
      null,
      v_actor_id);
  end if;
  v_diff := data.join_diffs(v_diff, pallas_project.change_next_status(v_actor_id, v_status_name, v_status_value, v_actor_id, 'Status purchase'));

  v_notified :=
    data.process_diffs_and_notify_current_object(
      v_diff,
      in_client_id,
      in_request_id,
      data.get_object_id(data.get_object_code(v_actor_id) || '_next_statuses'));
  assert v_notified;
end;
$$
language plpgsql;
