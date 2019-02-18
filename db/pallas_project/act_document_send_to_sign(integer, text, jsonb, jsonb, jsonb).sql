-- drop function pallas_project.act_document_send_to_sign(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_send_to_sign(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_document_id integer := data.get_object_id(v_document_code);
  v_actor_id integer :=data.get_active_actor_id(in_client_id);

  v_system_document_participants jsonb;
  v_person_code text;
  v_unsined_count integer;

  v_message text := 'Вам на подпись пришёл документ';

  v_changes jsonb[];
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;

  v_system_document_participants := data.get_attribute_value_for_share(v_document_id, 'system_document_participants');

  v_changes := array[]::jsonb[];

  v_changes := array_append(v_changes, data.attribute_change2jsonb('content', null, v_document_code || '_signers_list'));

-- Считаем, сколько осталось отсутствующих подписей. Если нисколько, меняем статус документа
  select count(1) into v_unsined_count
    from jsonb_each_text(v_system_document_participants) x 
    where x.value = 'false';
  if v_unsined_count = 0 then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('document_status', jsonb '"signed"'));
  else 
    v_changes := array_append(v_changes, data.attribute_change2jsonb('document_status', jsonb '"signing"'));
  end if;

  v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_document_id, 
                                               to_jsonb(v_changes));

  for v_person_code in (select x.key
                          from jsonb_each_text(v_system_document_participants) x
                          where x.value = 'false') loop
    perform pp_utils.add_notification(data.get_object_id(v_person_code), v_message, v_document_id, true);
  end loop;



  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
