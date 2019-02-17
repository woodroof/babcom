-- drop function pallas_project.act_document_delete_signer(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_delete_signer(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_list_code text := json.get_string(in_params, 'list_code');
  v_document_id integer := data.get_object_id(v_document_code);
  v_document_signers_list_id integer := data.get_object_id(v_document_code || '_signers_list');
  v_actor_id integer :=data.get_active_actor_id(in_client_id);

  v_system_document_participants jsonb;
  v_document_participants text;
  v_document_signers_list_participants text;
  v_document_status text;
  v_person_code text;

  v_document_content text[];
  v_content text[];
  v_changes jsonb[];
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;

  perform * from data.objects where id = v_document_id for update;
  perform * from data.objects where id = v_document_signers_list_id for update;

  v_document_status := json.get_string_opt(data.get_attribute_value(v_document_id, 'document_status'),'');
  assert v_document_status = 'draft';

  v_system_document_participants := data.get_attribute_value(v_document_id, 'system_document_participants');
  v_system_document_participants := v_system_document_participants - v_list_code;

  v_document_participants := pallas_project.get_document_participants(v_system_document_participants, v_actor_id, true);

  v_changes := array[]::jsonb[];

  select array_agg(x.key) into v_document_content
    from jsonb_each_text(v_system_document_participants) x;

  v_changes := array_append(v_changes, data.attribute_change2jsonb('system_document_participants', v_system_document_participants));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('document_participants', to_jsonb(v_document_participants)));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('content', to_jsonb(v_document_content), v_document_code || '_signers_list'));
  v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_document_id, 
                                               to_jsonb(v_changes));

  v_document_signers_list_participants := pallas_project.get_document_participants(v_system_document_participants, v_actor_id);
  v_content := pallas_project.get_document_possible_signers(v_document_id);

  perform data.change_object_and_notify(v_document_signers_list_id, 
                                        jsonb_build_array(
                                          data.attribute_change2jsonb('document_signers_list_participants', to_jsonb(v_document_signers_list_participants)),
                                          data.attribute_change2jsonb('content', to_jsonb(v_content))
                                        ),
                                        v_actor_id);

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
