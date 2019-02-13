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
  v_coin_attribute_id integer = data.get_attribute_id('system_person_coin');
  v_status_prices integer[] := data.get_integer_array_param(v_status_name || '_status_prices');
  v_current_status_value integer;
  v_current_coins integer;
  v_price integer;
  v_diff jsonb;
  v_notified boolean;
begin
  assert in_request_id is not null;
  assert in_user_params is null;
  assert in_default_params is null;

  select json.get_integer(av.value)
  into v_current_status_value
  from data.attribute_values av
  where
    av.object_id = v_actor_id and
    av.attribute_id = v_status_attribute_id
  for update;

  assert v_current_status_value is not null;

  -- todo за деньги

  select json.get_integer(av.value)
  into v_current_coins
  from data.attribute_values av
  where
    av.object_id = v_actor_id and
    av.attribute_id = v_coin_attribute_id
  for update;

  assert v_current_coins is not null;

  select sum(v_status_prices[value])
  into v_price
  from unnest(array[1, 2, 3]) a(value)
  where
    value > v_current_status_value and
    value <= v_status_value;

  if v_current_status_value >= v_status_value or v_price > v_current_coins then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
    return;
  end if;

  v_diff := pallas_project.change_coins(v_actor_id, v_current_coins - v_price, v_actor_id, 'Status buy');
  v_diff := data.join_diffs(v_diff, pallas_project.change_next_status(v_actor_id, v_status_name, v_status_value, v_actor_id, 'Status buy'));

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
