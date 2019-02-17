-- drop function pallas_project.lef_document_temp_share_list(integer, text, integer, integer);

create or replace function pallas_project.lef_document_temp_share_list(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_system_document_temp_share_list_attribute_id integer := data.get_attribute_id('system_document_temp_share_list');
  v_system_document_temp_share_list integer[];
  v_document_temp_share_list_attribute_id integer := data.get_attribute_id('document_temp_share_list');
  v_document_temp_share_list text;

  v_content_attribute_id integer := data.get_attribute_id('content');
  v_content text[];

  v_changes jsonb[] := array[]::jsonb[];
  v_message_sent boolean;
begin
  assert in_request_id is not null;
  assert in_list_object_id is not null;

  v_system_document_temp_share_list := json.get_integer_array_opt(data.get_attribute_value_for_update(in_object_id, v_system_document_temp_share_list_attribute_id), array[]::integer[]);
  v_document_temp_share_list := json.get_string_opt(data.get_attribute_value_for_update(in_object_id, v_document_temp_share_list_attribute_id), '');
  v_content := json.get_string_array_opt(data.get_raw_attribute_value_for_update(in_object_id, v_content_attribute_id), array[]::text[]);

  v_system_document_temp_share_list := array_append(v_system_document_temp_share_list, in_list_object_id);
  v_changes := array_append(v_changes, data.attribute_change2jsonb(v_system_document_temp_share_list_attribute_id, to_jsonb(v_system_document_temp_share_list)));

  v_document_temp_share_list := v_document_temp_share_list || E'\n' || json.get_string_opt(data.get_attribute_value(in_list_object_id, 'title', v_actor_id), '');
  v_changes := array_append(v_changes, data.attribute_change2jsonb(v_document_temp_share_list_attribute_id, to_jsonb(v_document_temp_share_list)));

  v_content := array_remove(v_content, data.get_object_code(in_list_object_id));
  v_changes := array_append(v_changes, data.attribute_change2jsonb(v_content_attribute_id, to_jsonb(v_content)));

  -- рассылаем обновление списка себе
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               in_object_id, 
                                               to_jsonb(v_changes));
  if not v_message_sent then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
