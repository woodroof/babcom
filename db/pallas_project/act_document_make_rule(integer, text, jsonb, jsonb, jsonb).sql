-- drop function pallas_project.act_document_make_rule(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_make_rule(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_document_id integer := data.get_object_id(v_document_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_document_category text := json.get_string_opt(data.get_attribute_value_for_update(v_document_id, 'document_category'),'~');
  v_my_documents_id integer := data.get_object_id('my_documents');
  v_rules_documents_id integer := data.get_object_id('rules_documents');
  v_person_id integer;
  v_master_group_id integer := data.get_object_id('master');
  v_message_sent boolean;

  v_content text[];
begin
  assert in_request_id is not null;
  assert v_document_category = 'private';

  for v_person_id in select * from unnest(pallas_project.get_group_members('all_person')) loop
    v_content := json.get_string_array_opt(data.get_raw_attribute_value_for_share(v_my_documents_id, 'content', v_person_id), array[]::text[]);
    if array_position(v_content, v_document_code) is not null then
      perform pp_utils.list_remove_and_notify(v_my_documents_id, v_document_code, v_person_id);
      perform pp_utils.list_prepend_and_notify(v_rules_documents_id, v_document_code, v_person_id);
    end if;
  end loop;
  perform pp_utils.list_remove_and_notify(v_my_documents_id, v_document_code, v_master_group_id);
  perform pp_utils.list_prepend_and_notify(v_rules_documents_id, v_document_code, v_master_group_id);

  v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_document_id, 
                                               jsonb_build_array(data.attribute_change2jsonb('document_category', jsonb '"rule"')));

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
