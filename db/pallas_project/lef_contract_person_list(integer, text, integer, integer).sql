-- drop function pallas_project.lef_contract_person_list(integer, text, integer, integer);

create or replace function pallas_project.lef_contract_person_list(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_org_code text := json.get_string(data.get_attribute_value(in_object_id, 'contract_org'));
  v_person_code text := data.get_object_code(in_list_object_id);
  v_draft_id integer;
begin
  v_draft_id :=
    data.create_object(
      null,
      jsonb '[]' ||
      data.attribute_change2jsonb('is_visible', jsonb 'true', v_actor_id) ||
      data.attribute_change2jsonb('contract_org', to_jsonb(v_org_code)) ||
      data.attribute_change2jsonb('contract_person', to_jsonb(v_person_code)) ||
      data.attribute_change2jsonb('contract_reward', jsonb '0') ||
      data.attribute_change2jsonb('contract_description', jsonb '""'),
      'contract_draft');
  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, data.get_object_code(v_draft_id));
  perform data.set_attribute_value(in_object_id, 'is_visible', jsonb 'false');
end;
$$
language plpgsql;
