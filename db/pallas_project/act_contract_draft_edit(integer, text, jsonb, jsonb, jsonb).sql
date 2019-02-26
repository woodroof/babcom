-- drop function pallas_project.act_contract_draft_edit(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_contract_draft_edit(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_contract_code text := json.get_string(in_params);
  v_reward bigint := json.get_bigint(in_user_params, 'reward');
  v_description text := pp_utils.trim(json.get_string(in_user_params, 'description'));
  v_contract_id integer := data.get_object_id(v_contract_code);
  v_notified boolean;
begin
  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      v_contract_id,
      jsonb_build_object('contract_reward', v_reward, 'contract_description', v_description));
  if not v_notified then
    perform api_utils.create_ok_notification(in_request_id, in_client_id);
  end if;
end;
$$
language plpgsql;
