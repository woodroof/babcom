-- drop function pallas_project.act_unsuspend_contract(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_unsuspend_contract(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_contract_code text := json.get_string(in_params);
  v_contract_id integer := data.get_object_id(v_contract_code);
  v_contract_status text := json.get_string(data.get_attribute_value_for_update(v_contract_id, 'contract_status'));
  v_new_contract_status text;
  v_notified boolean;
begin
  if v_contract_status not in ('suspended', 'suspended_cancelled') then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Объект изменился, действие более не доступно');
    return;
  end if;

  if v_contract_status = 'suspended' then
    v_new_contract_status := 'active';
  else
    v_new_contract_status := 'cancelled';
  end if;

  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      v_contract_id,
      jsonb_build_object('contract_status', v_new_contract_status));
  assert v_notified;

  perform pallas_project.notify_contract(v_contract_id, 'Выплаты по контракту были возобновлены');
end;
$$
language plpgsql;
