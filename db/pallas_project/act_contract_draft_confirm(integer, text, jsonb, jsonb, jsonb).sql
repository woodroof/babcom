-- drop function pallas_project.act_contract_draft_confirm(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_contract_draft_confirm(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_contract_code text := json.get_string(in_params);
  v_contract_id integer := data.get_object_id(v_contract_code);
  v_org_code text := json.get_string(data.get_attribute_value(v_contract_id, 'contract_org'));
  v_person_code text := json.get_string(data.get_attribute_value(v_contract_id, 'contract_person'));
  v_reward bigint := json.get_bigint(data.get_attribute_value(v_contract_id, 'contract_reward'));
  v_description text := json.get_string(data.get_attribute_value(v_contract_id, 'contract_description'));
  v_new_contract_id integer;
begin
  v_new_contract_id :=
    pallas_project.create_contract(
      v_person_code,
      v_org_code,
      'unconfirmed',
      v_reward,
      v_description);
  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, data.get_object_code(v_new_contract_id));
  perform pallas_project.notify_contract(v_new_contract_id, 'Создан новый контракт');
  perform data.set_attribute_value(v_contract_id, 'is_visible', jsonb 'false', v_actor_id);
end;
$$
language plpgsql;
