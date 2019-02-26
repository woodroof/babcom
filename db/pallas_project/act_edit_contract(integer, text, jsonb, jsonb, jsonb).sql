-- drop function pallas_project.act_edit_contract(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_edit_contract(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_contract_code text := json.get_string(in_params);
  v_reward bigint := json.get_bigint(in_user_params, 'reward');
  v_description text := pp_utils.trim(json.get_string(in_user_params, 'description'));
  v_contract_id integer := data.get_object_id(v_contract_code);
  v_contract_status text := json.get_string(data.get_attribute_value_for_update(v_contract_id, 'contract_status'));
  v_notified boolean;
begin
  if v_contract_status not in ('unconfirmed') then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Контракт сменил статус и более не может быть отредактирован');
    return;
  end if;

  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      v_contract_id,
      jsonb_build_object('contract_reward', v_reward, 'contract_description', v_description));
  if v_notified then
    perform pallas_project.notify_contract(v_contract_id, 'Изменены условия контракта');
  else
    perform api_utils.create_ok_notification(in_request_id, in_client_id);
  end if;
end;
$$
language plpgsql;
