-- drop function pallas_project.act_document_add_to_my(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_add_to_my(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_document_id integer := data.get_object_id(v_document_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_document_category text := json.get_string_opt(data.get_attribute_value_for_share(v_document_id, 'document_category'),'~');
  v_my_documents_id integer := data.get_object_id('my_documents');
  v_official_documents_id integer := data.get_object_id('official_documents');
  v_rules_documents_id integer := data.get_object_id('rules_documents');
  v_system_document_is_my boolean := json.get_boolean_opt(data.get_raw_attribute_value_for_update(v_document_id, 'system_document_is_my', v_actor_id), false);
  v_message_sent boolean;
begin
  assert in_request_id is not null;
  assert not v_system_document_is_my;

  case v_document_category
  when 'private' then 
    perform pp_utils.list_prepend_and_notify(v_my_documents_id, v_document_code, v_actor_id);
  when 'official' then
    perform pp_utils.list_prepend_and_notify(v_official_documents_id, v_document_code, v_actor_id);
  when 'rule' then
    perform pp_utils.list_prepend_and_notify(v_rules_documents_id, v_document_code, v_actor_id);
  else
    null;
  end case;

  v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_document_id, 
                                               jsonb_build_array(data.attribute_change2jsonb('system_document_is_my', jsonb 'true', v_actor_id)));

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;

  perform api_utils.create_ok_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;
