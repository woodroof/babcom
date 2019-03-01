-- drop function pallas_project.act_med_drugs_add_drug(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_med_drugs_add_drug(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_category text := json.get_string(in_params, 'category');
  v_med_drug_code text;
  v_med_drug_id  integer;
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_med_drugs_id integer := data.get_object_id('med_drugs');

  v_master_group_id integer := data.get_object_id('master');
  v_med_drug_qr_link_attribute_id integer := data.get_attribute_id('med_drug_qr_link');
  v_content_attribute_id integer := data.get_attribute_id('content');

  v_changes jsonb[];
  v_message_sent boolean;
  v_content text[];
begin
  assert in_request_id is not null;
  -- создаём новый наркотик

  v_med_drug_id := data.create_object(
    null,
    jsonb_build_array(
      jsonb_build_object('code', 'med_drug_category', 'value', v_category),
      jsonb_build_object('code', 'med_drug_effect', 'value', v_category),
      jsonb_build_object('code', 'med_drug_status', 'value', 'not_used')
    ),
    'med_drug');

  v_med_drug_code := data.get_object_code(v_med_drug_id);

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_med_drug_id, v_med_drug_qr_link_attribute_id, to_jsonb(data.get_string_param('objects_url') || v_med_drug_code), null);

  -- Добавляем наркотик в список 
  v_changes := array[]::jsonb[];
  v_content := json.get_string_array_opt(data.get_raw_attribute_value_for_update(v_med_drugs_id, v_content_attribute_id), array[]::text[]);
  v_content := array_prepend(v_med_drug_code, v_content);
  v_changes := array_append(v_changes, data.attribute_change2jsonb(v_content_attribute_id, to_jsonb(v_content)));
  v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_med_drugs_id, 
                                               to_jsonb(v_changes));
  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
