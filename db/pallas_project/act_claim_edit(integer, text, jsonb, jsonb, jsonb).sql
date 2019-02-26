-- drop function pallas_project.act_claim_edit(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_claim_edit(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_claim_code text := json.get_string(in_params, 'claim_code');
  v_title text := json.get_string(in_user_params, 'title');
  v_text text := json.get_string(in_user_params, 'text');
  v_claim_id integer := data.get_object_id(v_claim_code);
  v_claim_chat_id integer := data.get_object_id(v_claim_code || '_chat');
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_old_title text;
  v_old_text text;
  v_claim_author text := json.get_string(data.get_raw_attribute_value_for_share(v_claim_id, 'claim_author'));
  v_claim_status text := json.get_string(data.get_raw_attribute_value_for_share(v_claim_id, 'claim_status'));
  v_changes jsonb[];
  v_chat_changes jsonb[];

  v_claim_text_attribute_id integer := data.get_attribute_id('claim_text');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;
  assert (v_claim_status = 'draft'and data.get_object_id(v_claim_author) = v_actor_id) or pp_utils.is_in_group(v_actor_id, 'master');

  v_old_title := json.get_string_opt(data.get_raw_attribute_value_for_update(v_claim_id, v_title_attribute_id), '');
  v_old_text := json.get_string_opt(data.get_raw_attribute_value_for_update(v_claim_id, v_claim_text_attribute_id), '');

  v_changes := array[]::jsonb[];
  v_chat_changes := array[]::jsonb[];
  if v_old_title <> v_title then
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_title_attribute_id, to_jsonb(v_title)));
    v_chat_changes := array_append(v_changes, data.attribute_change2jsonb(v_title_attribute_id, to_jsonb('Обсуждение иска ' || v_title)));
  end if;
  if v_old_text <> v_text then
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_claim_text_attribute_id, to_jsonb(v_text)));
  end if;
  if array_length(v_chat_changes, 1) > 0 then
    perform data.change_object_and_notify(v_claim_chat_id, to_jsonb(v_chat_changes), v_actor_id);
  end if;

  if array_length(v_changes, 1) > 0 then
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_claim_id, 
                                                 to_jsonb(v_changes));
  end if;

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
