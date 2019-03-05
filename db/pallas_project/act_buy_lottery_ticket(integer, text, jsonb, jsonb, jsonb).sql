-- drop function pallas_project.act_buy_lottery_ticket(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_buy_lottery_ticket(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_economy_type text := json.get_string(data.get_attribute_value_for_share(v_actor_id, 'system_person_economy_type'));
  v_price integer := data.get_integer_param('lottery_ticket_price');
  v_object_id integer := data.get_object_id('lottery');
  v_lottery_ticket_count integer := json.get_integer_opt(data.get_raw_attribute_value_for_update(v_object_id, 'lottery_ticket_count', v_actor_id), 0);
  v_current_sum bigint := json.get_bigint(data.get_attribute_value_for_update(v_actor_id, 'system_money'));
  v_lottery_status text := json.get_string(data.get_attribute_value_for_share(v_object_id, 'lottery_status'));
  v_diff jsonb;
  v_notified boolean;
begin
  assert in_request_id is not null;

  if v_economy_type != 'asters' then
    -- Потенциальный выигравший
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
    return;
  end if;

  if v_lottery_status != 'active' then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Лотерея заночилась', 'К сожалению, вы не успели, билеты более не продаются.');
    return;
  end if;

  if v_current_sum < v_price then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Не хватает денег', 'На вашем счёте недостаточно средств для покупки лотерейных билетов.');
    return;
  end if;

  v_diff := pallas_project.change_money(v_actor_id, v_current_sum - v_price, v_actor_id, 'Status purchase');
  perform pallas_project.create_transaction(
    v_actor_id,
    null,
    'Покупка лотерейного билета',
    -v_price,
    v_current_sum - v_price,
    null,
    null,
    v_actor_id,
    array[v_actor_id]);
  v_diff :=
    v_diff ||
    data.change_object(
      v_object_id,
      jsonb '[]' || data.attribute_change2jsonb('lottery_ticket_count', to_jsonb(v_lottery_ticket_count + 1), v_actor_id),
      v_actor_id);

  v_notified :=
    data.process_diffs_and_notify_current_object(
      v_diff,
      in_client_id,
      in_request_id,
      v_object_id);
  assert v_notified;
end;
$$
language plpgsql;
