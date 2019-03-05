-- drop function pallas_project.act_customs_package_check(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_customs_package_check(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_package_code text := json.get_string(in_params, 'package_code');
  v_package_id integer := data.get_object_id(v_package_code);

  v_custons_new_id integer := data.get_object_id('customs_new');
  v_system_customs_checking boolean := json.get_boolean_opt(data.get_attribute_value_for_update(v_custons_new_id, 'system_customs_checking'), false);
  v_package_status text := json.get_string(data.get_attribute_value_for_update(v_package_id, 'package_status'));
  v_check_result boolean;

  v_changes jsonb := jsonb '[]';
begin
  if v_system_customs_checking then
    perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Предупреждение',
      'Нельзя начать новую проверку, пока не закончилась предыдущая.'); 
    return;
  end if;
  if v_package_status <> 'new' then
    perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Предупреждение',
      'Нельзя проверять посылку в этом статусе'); 
    return;
  end if;

  v_changes :=
    v_changes ||
    jsonb_build_object('id', v_package_id, 'changes', jsonb '[]' || data.attribute_change2jsonb('package_status', '"checking"')) ||
    jsonb_build_object('id', v_custons_new_id, 'changes', jsonb '[]' || data.attribute_change2jsonb('system_customs_checking', jsonb 'true'));

  perform data.process_diffs_and_notify(data.change_objects(v_changes));

  perform data.create_job(clock_timestamp() + ('10 seconds')::interval, 
      'pallas_project.job_customs_package_check', 
      in_params);

  perform api_utils.create_ok_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;
