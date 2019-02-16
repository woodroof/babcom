-- drop function pallas_project.act_document_add_to_my(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_add_to_my(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_document_id integer := data.get_object_id(v_document_code);
  v_actor_id integer :=data.get_active_actor_id(in_client_id);
  v_system_document_category text := json.get_string_opt(data.get_attribute_value(v_document_id, 'system_document_category'),'~');
  v_my_documents_id integer := data.get_object_id('my_documents');
  v_official_documents_id integer := data.get_object_id('official_documents');
begin
  assert in_request_id is not null;

  case v_system_document_category
  when 'private' then 
    perform pp_utils.list_prepend_and_notify(v_my_documents_id, v_document_code, v_actor_id);
  when 'official' then
    perform pp_utils.list_prepend_and_notify(v_official_documents_id, v_document_code, v_actor_id);
  else
    null;
  end case;

  perform api_utils.create_ok_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;
