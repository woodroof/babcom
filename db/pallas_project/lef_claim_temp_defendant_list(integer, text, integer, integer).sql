-- drop function pallas_project.lef_claim_temp_defendant_list(integer, text, integer, integer);

create or replace function pallas_project.lef_claim_temp_defendant_list(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id integer :=data.get_active_actor_id(in_client_id);
  v_claim_id integer := json.get_integer(data.get_attribute_value_for_share(in_object_id, 'system_claim_id'));
  v_claim_code text := data.get_object_code(v_claim_id);
  v_list_code text := data.get_object_code(in_list_object_id);

  v_claim_defendant text := json.get_string_opt(data.get_attribute_value_for_share(v_claim_id, 'claim_defendant'), null);

  v_changes jsonb[];
begin
  assert in_request_id is not null;
  assert in_list_object_id is not null;

  if v_claim_defendant is distinct from v_list_code then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('claim_defendant', to_jsonb(v_list_code)));
  end if;

  perform data.change_object_and_notify(v_claim_id, to_jsonb(v_changes), v_actor_id);

  perform api_utils.create_go_back_action_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;
