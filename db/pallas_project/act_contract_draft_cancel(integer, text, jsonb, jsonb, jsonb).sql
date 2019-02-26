-- drop function pallas_project.act_contract_draft_cancel(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_contract_draft_cancel(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_contract_code text := json.get_string(in_params);
  v_contract_id integer := data.get_object_id(v_contract_code);
  v_org_code text := json.get_string(data.get_attribute_value(v_contract_id, 'contract_org'));
begin
  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_org_code);
  perform data.set_attribute_value(v_contract_id, 'is_visible', jsonb 'false', v_actor_id);
end;
$$
language plpgsql;
