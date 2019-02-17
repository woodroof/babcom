-- drop function pallas_project.lef_document_signers_list(integer, text, integer, integer);

create or replace function pallas_project.lef_document_signers_list(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id integer :=data.get_active_actor_id(in_client_id);
  v_document_code text := replace(data.get_object_code(in_object_id), '_signers_list', '');
  v_document_id integer := data.get_object_id(v_document_code);
  v_system_document_participants jsonb;
  v_document_participants text;
  v_document_signers_list_participants text;
  v_title_attribute_id integer := data.get_attribute_id('title');

  v_list_object_code text := data.get_object_code(in_list_object_id);

  v_changes jsonb[];
  v_message_sent boolean;

  v_document_content text[];
  v_content text[];

  v_name record;
  v_names jsonb;
begin
  assert in_request_id is not null;
  assert in_list_object_id is not null;

  perform * from data.objects where id = v_document_id for update;
  perform * from data.objects where id = in_object_id for update;

  v_system_document_participants := data.get_attribute_value(v_document_id, 'system_document_participants');
  v_system_document_participants := v_system_document_participants || jsonb_build_object('code', v_list_object_code, 'signed', false);

  v_document_participants := pallas_project.get_document_participants(v_system_document_participants, v_actor_id, true);
  v_document_signers_list_participants := pallas_project.get_document_participants(v_system_document_participants, v_actor_id);

  select array_agg(x.code) into v_document_content
    from jsonb_to_recordset(v_system_document_participants) as x(code text);

  perform data.change_object_and_notify(v_document_id,
                                        jsonb_build_array(
                                          data.attribute_change2jsonb('system_document_participants', v_system_document_participants),
                                          data.attribute_change2jsonb('document_participants', to_jsonb(v_document_participants)),
                                          data.attribute_change2jsonb('content', to_jsonb(v_document_content), in_object_id)
                                        ),
                                        null);

  v_content := pallas_project.get_document_possible_signers(v_document_id);

  -- рассылаем обновление списка себе
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               in_object_id, 
                                               jsonb_build_array(
                                                 data.attribute_change2jsonb('document_signers_list_participants', to_jsonb(v_document_signers_list_participants)),
                                                 data.attribute_change2jsonb('content', to_jsonb(v_content))
                                               ));
  if not v_message_sent then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
