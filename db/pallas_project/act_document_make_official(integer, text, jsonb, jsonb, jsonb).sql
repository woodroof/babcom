-- drop function pallas_project.act_document_make_official(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_make_official(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
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
  v_person_id integer;
  v_message_sent boolean;
begin
  assert in_request_id is not null;
  assert v_system_document_category = 'private';

  v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_document_id, 
                                               jsonb_build_array(data.attribute_change2jsonb('system_document_category', jsonb '"official"')));

  for v_person_id in select * from unnest(pallas_project.get_group_members('all_person')) loop
    perform pp_utils.list_remove_and_notify(v_my_documents_id, v_document_code, v_person_id);
    perform pp_utils.list_prepend_and_notify(v_official_documents_id, v_document_code, v_person_id);
  end loop;

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
