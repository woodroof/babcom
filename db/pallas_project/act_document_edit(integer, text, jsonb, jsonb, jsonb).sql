-- drop function pallas_project.act_document_edit(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_edit(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_title text := json.get_string(in_user_params, 'title');
  v_document_text text := json.get_string(in_user_params, 'document_text');
  v_document_id integer := data.get_object_id(v_document_code);
  v_actor_id integer :=data.get_active_actor_id(in_client_id);

  v_changes jsonb[];
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;

  perform * from data.objects where id = v_document_id for update;
  v_changes := array[]::jsonb[];

  v_changes := array_append(v_changes, data.attribute_change2jsonb('title', to_jsonb(v_title)));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('document_text', to_jsonb(v_document_text)));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('document_last_edit_time', to_jsonb(to_char(clock_timestamp(),'DD.MM.YYYY hh24:mi:ss')), v_actor_id));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('document_last_edit_time', to_jsonb(to_char(clock_timestamp(),'DD.MM.YYYY hh24:mi:ss')), 'master'));
  v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_document_id, 
                                                 to_jsonb(v_changes));

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
