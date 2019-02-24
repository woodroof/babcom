-- drop function pallas_project.act_document_create(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_create(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_title text := json.get_string_opt(in_user_params, 'title', null);
  v_document_code text;
  v_document_id integer;

  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_my_documents_id integer := data.get_object_id('my_documents');
  v_master_group_id integer := data.get_object_id('master');
begin
  assert in_request_id is not null;

  -- Создаём документ
  v_document_id := data.create_object(
  null,
    jsonb_build_array(
      jsonb_build_object('code', 'title', 'value', v_document_title),
      jsonb_build_object('code', 'document_category', 'value', 'private'),
      jsonb_build_object('code', 'system_document_author', 'value', v_actor_id),
      jsonb_build_object('code', 'document_author', 'value', json.get_string(data.get_attribute_value(v_actor_id, 'title')) , 'value_object_id', v_master_group_id),
      jsonb_build_object('code', 'document_last_edit_time', 'value', to_char(clock_timestamp(),'DD.MM.YYYY hh24:mi:ss'), 'value_object_id', v_master_group_id),
      jsonb_build_object('code', 'document_last_edit_time', 'value', to_char(clock_timestamp(),'DD.MM.YYYY hh24:mi:ss'), 'value_object_id', v_actor_id),
      jsonb_build_object('code', 'system_document_is_my', 'value', true, 'value_object_id', v_actor_id)
    ),
  'document');

  v_document_code := data.get_object_code(v_document_id);

  if not pp_utils.is_in_group(v_actor_id, 'master') then
    perform pp_utils.list_prepend_and_notify(v_my_documents_id, v_document_code, v_actor_id);
  end if;
  perform pp_utils.list_prepend_and_notify(v_my_documents_id, v_document_code, v_master_group_id);

  -- Заходим в документ
  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_document_code);
end;
$$
language plpgsql;
