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
  v_med_health jsonb := to_jsonb(json.get_string(in_user_params, 'med_health'));
  v_med_clinic_money integer := json.get_integer(in_user_params, 'med_clinic_money');
  v_disease text;
  v_level integer;
  v_diagnosted integer;

  v_person_id integer := data.get_object_id(v_person_code);
  v_child_person_id integer;

  v_old_med_health jsonb;
  v_old_level integer;

  v_disease_params jsonb;
  v_message_text text ;

  v_health_care_status integer;
  v_orig_health_care_status integer;

  v_time_to_next integer;
  v_next_level integer;
  v_job_id integer;

  v_message_sent boolean := false;
  v_changes jsonb[];
begin

  v_person_id := json.get_integer_opt(data.get_attribute_value(v_person_id, 'system_person_original_id'), v_person_id);
  v_person_code := data.get_object_code(v_person_id);

  v_old_med_health := coalesce(data.get_attribute_value_for_update(v_person_code || '_med_health', 'med_health'), jsonb '{}');

  for v_disease in (select * from jsonb_object_keys(v_med_health)) loop
    select x.job, x.level into v_job_id, v_old_level
    from jsonb_to_record(jsonb_extract_path(v_old_med_health, v_disease)) as x(job integer, level integer);
    select x.level, x_diagnosted into v_level, v_diagnosted
    from jsonb_to_record(jsonb_extract_path(v_med_health, v_disease)) as x(level integer, diagnosted integer);

    if v_level is null then 
      v_level := 0;
    end if;
    if coalesce(v_old_level, 0) <> v_level then

      v_message_text := data.get_string_param('med_' || v_disease || '_' || v_level);
      v_disease_params := data.get_param('med_' || v_disease );
      select x.time, coalesce(x.next_level, v_level + 1) into v_time_to_next, v_next_level
      from jsonb_to_record(jsonb_extract_path(v_disease_params, 'l'||v_level)) as x(time integer, next_level integer);

      delete from data.jobs where id = v_job_id;

      if v_time_to_next is not null then
        v_job_id := data.create_job(clock_timestamp() + (v_time_to_next::text || ' minutes')::interval, 
          'pallas_project.job_med_set_disease_level', 
          format('{"person_code": "%s", "disease": "%s", "level": %s}', v_person_code, v_disease, v_next_level)::jsonb);
      end if;

      if coalesce(v_message_text,'') <> '' then
        perform pp_utils.add_notification(v_person_id, v_message_text);
        for v_child_person_id in (select * from unnest(json.get_integer_array_opt(data.get_attribute_value(v_person_id, ''), array[]::integer[]))) loop
          perform pp_utils.add_notification(v_child_person_id, v_message_text);
        end loop;
      end if;

      v_med_health := jsonb_set(v_med_health, 
                                array[v_disease]::text[], 
                                jsonb_strip_nulls(format('{"level": %s, "start": "%s", "diagnosted": %s, "job": %s}', 
                                                          v_level, 
                                                          pp_utils.format_date(clock_timestamp()), 
                                                          coalesce(v_diagnosted::text, 'null'), 
                                                          coalesce(v_job_id::text, 'null')
                                                        )::jsonb));

    end if;
  end loop;

  if pp_utils.is_in_group(v_actor_id, 'unofficial_doctor') then
    v_changes := array[]::jsonb[];
    v_changes := array_append(v_changes, data.attribute_change2jsonb('system_money', to_jsonb(v_med_clinic_money)));
    perform data.change_object_and_notify(data.get_object_id('org_clean_asteroid'), 
                                         to_jsonb(v_changes),
                                         null);
  end if;

  v_changes := array[]::jsonb[];
  v_changes := array_append(v_changes, data.attribute_change2jsonb('med_health', v_med_health));
  perform data.change_object_and_notify(data.get_object_id(v_person_code || '_med_health'), 
                                        to_jsonb(v_changes),
                                        null);
  if pp_utils.is_in_group(v_actor_id, 'unofficial_doctor') then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('med_clinic_money', to_jsonb(v_med_clinic_money)));
  end if;

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
