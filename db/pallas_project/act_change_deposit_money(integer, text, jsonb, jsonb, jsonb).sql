-- drop function pallas_project.act_change_deposit_money(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_change_deposit_money(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_object_code text := json.get_string(in_params);
  v_object_id integer := data.get_object_id(v_object_code);
  v_money_diff integer := json.get_integer(in_user_params, 'money_diff');
  v_money integer := json.get_integer(data.get_raw_attribute_value_for_update(v_object_id, 'system_person_deposit_money'));
  v_comment text := pp_utils.trim(json.get_string(in_user_params, 'comment'));
  v_diff jsonb;
  v_notified boolean;
begin
  if v_money_diff = 0 then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
    return;
  end if;

  v_money := v_money + v_money_diff;

  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      v_object_id,
      format(
        '[
          {"code": "system_person_deposit_money", "value": %s},
          {"code": "person_deposit_money", "value": %s, "value_object_id": %s},
          {"code": "person_deposit_money", "value": %s, "value_object_code": "master"}
        ]',
        v_money,
        v_money,
        v_object_id,
        v_money)::jsonb,
      'Изменение количества доступных денег на инвестиционном счёте мастером');
  assert v_notified;

  perform pp_utils.add_notification(
    v_object_id,
    format(
      E'Изменение суммы остатка на инвестиционном счёте.\nИзменение: %s\nНовый остаток: %s\n%s',
      pp_utils.format_money(v_money_diff),
      pp_utils.format_money(v_money),
      v_comment),
    v_object_id,
    true);
end;
$$
language plpgsql;
