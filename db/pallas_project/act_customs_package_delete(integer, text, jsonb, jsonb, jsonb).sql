-- drop function pallas_project.act_customs_package_delete(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_customs_package_delete(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_package_code text := json.get_string(in_params, 'package_code');
  v_from_list text := json.get_string(in_params, 'from_list');
  v_package_id integer := data.get_object_id(v_package_code);
  v_package_status text := json.get_string(data.get_attribute_value_for_update(v_package_id, 'package_status'));
  v_customs_id integer := data.get_object_id(v_from_list);
  v_content text[] := json.get_string_array(data.get_raw_attribute_value_for_update(v_customs_id, 'content', null));
  v_changes jsonb := jsonb '[]';
begin
  v_content := array_remove(v_content, v_package_code);
  v_changes :=
    v_changes ||
    jsonb_build_object('id', v_package_id, 'changes', jsonb '[]' || data.attribute_change2jsonb('is_visible', jsonb 'false', 'master') ||
                                                                    data.attribute_change2jsonb('is_visible', jsonb 'false', 'customs_officer') ||
                                                                    data.attribute_change2jsonb('package_status', jsonb '"frozen"')) ||
    jsonb_build_object('id', v_customs_id, 'changes', jsonb '[]' || data.attribute_change2jsonb('content', to_jsonb(v_content)));
  perform data.process_diffs_and_notify(data.change_objects(v_changes));

  perform api_utils.create_ok_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;
