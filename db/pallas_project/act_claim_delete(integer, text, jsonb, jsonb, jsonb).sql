-- drop function pallas_project.act_claim_delete(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_claim_delete(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_claim_code text := json.get_string(in_params, 'claim_code');
  v_claim_id integer := data.get_object_id(v_claim_code);
  v_claim_chat_id integer := data.get_object_id(v_claim_code || '_chat');
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_claim_author text := json.get_string(data.get_raw_attribute_value_for_share(v_claim_id, 'claim_author'));
  v_claim_status text := json.get_string(data.get_raw_attribute_value_for_share(v_claim_id, 'claim_status'));
  v_changes jsonb[];
begin
  assert in_request_id is not null;
  assert (v_claim_status = 'draft'and data.get_object_id(v_claim_author) = v_actor_id) or pp_utils.is_in_group(v_actor_id, 'master');

  v_changes := array[]::jsonb[];
  v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', jsonb 'false'));

  perform data.change_object_and_notify(v_claim_id, 
                                        to_jsonb(v_changes),
                                        v_actor_id);

  v_changes := array[]::jsonb[];
  v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', jsonb 'false', v_claim_chat_id));

  perform data.change_object_and_notify(v_claim_chat_id, 
                                        to_jsonb(v_changes),
                                        v_actor_id);

  perform api_utils.create_go_back_action_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;
