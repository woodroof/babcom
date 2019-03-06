-- drop function pallas_project.act_med_cure(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_med_cure(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_med_computer_code text := json.get_string(in_params, 'med_computer_code');
  v_person_code text := json.get_string(in_params, 'person_code');
  v_disease text := json.get_string(in_user_params, 'disease');
  v_level integer := json.get_integer(in_user_params, 'level');
  v_message text := json.get_string(in_user_params, 'message');
  v_med_clinic_money_price integer := json.get_integer(in_user_params, 'med_clinic_money_price');
  v_med_clinic_panacelin_price integer := json.get_integer(in_user_params, 'med_clinic_panacelin_price');
  v_diagnosted integer;

  v_clinic_money integer;
  v_resource_panacelin integer;

  v_person_id integer := data.get_object_id(v_person_code);
  v_child_person_id integer;

  v_med_health jsonb;

  v_health_care_status integer;
  v_orig_health_care_status integer;

  v_time_to_next integer;
  v_next_level integer;
  v_job_id integer;

  v_message_sent boolean := false;
  v_changes jsonb[];
  v_diff jsonb;
  v_med_skill integer := json.get_integer_opt(data.get_attribute_value(v_actor_id, 'system_person_med_skill'), null);
  v_is_stimulant boolean := json.get_boolean_opt(data.get_attribute_value(v_actor_id, 'system_person_is_stimulant_used'), null);

begin

  v_person_id := json.get_integer_opt(data.get_attribute_value(v_person_id, 'system_person_original_id'), v_person_id);
  v_person_code := data.get_object_code(v_person_id);

  perform pallas_project.act_med_set_disease_level(
        null, 
        null, 
        format('{"person_code": "%s", "disease": "%s", "level": %s, "without_message": true}', v_person_code, v_disease, v_level)::jsonb, 
        null, 
        null);

  if coalesce(v_message,'') <> '' then
    perform pp_utils.add_notification(v_person_id, v_message);
    for v_child_person_id in (select * from unnest(json.get_integer_array_opt(data.get_attribute_value(v_person_id, 'system_person_doubles_id_list'), array[]::integer[]))) loop
      perform pp_utils.add_notification(v_child_person_id, v_message);
    end loop;
  end if;

  v_changes := array[]::jsonb[];
  if pp_utils.is_in_group(v_actor_id, 'unofficial_doctor') then
    v_clinic_money := json.get_bigint_opt(data.get_attribute_value('org_clean_asteroid', 'system_money'), 0);
    v_diff := pallas_project.change_money(data.get_object_id('org_clean_asteroid'), v_clinic_money - v_med_clinic_money_price, v_actor_id, 'Cure');
    perform pallas_project.create_transaction(
          data.get_object_id('org_clean_asteroid'),
          null,
          'Покупка чистящих средств',
          -v_med_clinic_money_price,
          v_clinic_money - v_med_clinic_money_price,
          null,
          null,
          v_actor_id,
           array[
            data.get_object_id('org_clean_asteroid_head'),
            data.get_object_id('org_clean_asteroid_economist'),
            data.get_object_id('org_clean_asteroid_auditor'),
            data.get_object_id('org_clean_asteroid_temporary_auditor')]);
      perform data.process_diffs_and_notify(v_diff);

  elsif pp_utils.is_in_group(v_actor_id, 'doctor') then
    v_resource_panacelin := json.get_bigint_opt(data.get_attribute_value('org_clinic', 'system_resource_panacelin'), 0);
    v_changes := array_append(v_changes, data.attribute_change2jsonb('system_resource_panacelin', to_jsonb(v_resource_panacelin - v_med_clinic_panacelin_price)));
    perform data.change_object_and_notify(data.get_object_id('org_clean_asteroid'), 
                                         to_jsonb(v_changes),
                                         null);
  end if;

  v_changes := array[]::jsonb[];
  v_med_health := coalesce(data.get_attribute_value_for_share(v_person_code || '_med_health', 'med_health'), jsonb '{}');
  v_changes := array_append(v_changes, data.attribute_change2jsonb('med_health', v_med_health));
  if pp_utils.is_in_group(v_actor_id, 'unofficial_doctor') then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('med_clinic_money', to_jsonb(v_clinic_money - v_med_clinic_money_price)));
  elsif pp_utils.is_in_group(v_actor_id, 'doctor') then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('resource_panacelin', to_jsonb(v_resource_panacelin - v_med_clinic_panacelin_price)));
  end if;

  v_changes := array_append(v_changes, data.attribute_change2jsonb('med_skill', to_jsonb(v_med_skill)));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('is_stimulant_used', to_jsonb(v_is_stimulant)));

  select coalesce(max(json.get_integer_opt(data.get_attribute_value_for_share(x, 'system_person_health_care_status'), 0)), 0) into v_health_care_status 
    from unnest(json.get_integer_array_opt(data.get_attribute_value(v_person_id, 'system_person_doubles_id_list'), array[]::integer[])) as x;
  v_orig_health_care_status := json.get_integer_opt(data.get_attribute_value_for_share(v_person_id, 'system_person_health_care_status'), 0);
  if v_orig_health_care_status > v_health_care_status then
    v_health_care_status := v_orig_health_care_status;
  end if;
  v_changes := array_append(v_changes, data.attribute_change2jsonb('med_health_care_status', to_jsonb(v_health_care_status)));

  v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               data.get_object_id(v_med_computer_code), 
                                               to_jsonb(v_changes));
  if not v_message_sent then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
  end;
$$
language plpgsql;
