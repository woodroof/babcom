-- drop function pallas_project.act_change_money(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_change_money(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_object_code text := json.get_string(in_params);
  v_object_id integer := data.get_object_id(v_object_code);
  v_money_diff integer := json.get_integer(in_user_params, 'money_diff');
  v_money integer := json.get_integer(data.get_raw_attribute_value_for_update(v_object_id, 'system_money'));
  v_comment text := pp_utils.trim(json.get_string(in_user_params, 'comment'));
  v_diff jsonb;
  v_notified boolean;
begin
  if v_money_diff = 0 then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
    return;
  end if;

  if v_comment = '' then
    v_comment := 'Перевод средств';
  else
    v_comment := E'Перевод средств\nКомментарий:\n' || v_comment;
  end if;

  v_diff :=
    pallas_project.change_money(
      v_object_id,
      v_money + v_money_diff,
      v_actor_id,
      'Изменение количества доступных денег мастером');
  v_notified :=
    data.process_diffs_and_notify_current_object(
      v_diff,
      in_client_id,
      in_request_id,
      v_object_id);
  assert v_notified;

  perform pallas_project.create_transaction(
    v_object_id,
    null,
    v_comment,
    v_money_diff,
    v_money + v_money_diff,
    null,
    null,
    v_actor_id,
    array[v_object_id]);
  perform pallas_project.notify_transfer_receiver(v_object_id, v_money_diff);
end;
$$
language plpgsql;
