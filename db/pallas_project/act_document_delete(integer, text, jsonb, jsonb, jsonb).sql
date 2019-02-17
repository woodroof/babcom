-- drop function pallas_project.act_document_delete(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_delete(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_document_id integer := data.get_object_id(v_document_code);
  v_actor_id integer :=data.get_active_actor_id(in_client_id);
  v_master_group_id integer := data.get_object_id('master');

  v_document_author integer;

  v_changes jsonb[];
begin
  assert in_request_id is not null;

  perform * from data.objects where id = v_document_id for update;

  v_document_author := json.get_integer(data.get_attribute_value(v_document_id, 'system_document_author'));
  v_changes := array[]::jsonb[];

  v_changes := array_append(v_changes, data.attribute_change2jsonb('document_status', jsonb '"deleted"'));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', to_jsonb(false), null));

  perform data.change_object_and_notify(v_document_id, 
                                        to_jsonb(v_changes),
                                        v_actor_id);

  perform api_utils.create_go_back_action_notification(in_client_id, in_request_id);

end;
$$
language plpgsql;
