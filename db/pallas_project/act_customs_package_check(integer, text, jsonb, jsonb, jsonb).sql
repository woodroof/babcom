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

  v_message_sent boolean := false;
  v_change jsonb[] := array[]::jsonb[];
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

  v_change := array_append(v_change, data.attribute_change2jsonb('package_status', '"checking"'));
  perform data.change_object_and_notify(v_package_id, 
                                        to_jsonb(v_change),
                                        null);

  v_change := array[]::jsonb[];
  v_change := array_append(v_change, data.attribute_change2jsonb('system_customs_checking', jsonb 'true'));
  perform data.change_object_and_notify(v_custons_new_id, 
                                        to_jsonb(v_change),
                                        null);
  perform data.create_job(clock_timestamp() + ('1 minute')::interval, 
      'pallas_project.job_customs_package_check', 
      in_params);
  if not v_message_sent then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
