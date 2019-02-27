-- drop function pallas_project.act_med_set_disease_level(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_med_set_disease_level(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_person_code text := json.get_string(in_params, 'person_code');
  v_disease text := json.get_string_opt(in_params, 'disease', null);
  v_level integer := json.get_integer_opt(in_params, 'level', null);
  v_diagnosted integer := json.get_integer_opt(coalesce(in_user_params,'{}'::jsonb), 'diagnosted', null);

  v_person_id integer := data.get_object_id(v_person_code);

  v_med_health jsonb := data.get_attribute_value_for_update(v_person_code || '_med_health', 'med_health');
  v_disease_params jsonb;
  v_message_text text ;

  v_time_to_next integer;
  v_next_level integer;
  v_job_id integer;

  v_message_sent boolean := false;
  v_changes jsonb[];
begin

  if v_disease is null or v_level is null then
    v_disease := json.get_string(in_user_params, 'disease');
    v_level := json.get_integer(in_user_params, 'level');
  end if;

  v_message_text := data.get_string_param('med_' || v_disease || '_' || v_level);
  v_disease_params := data.get_param('med_' || v_disease );

  select x.time, coalesce(x.next_level, v_level + 1) into v_time_to_next, v_next_level
  from jsonb_to_record(jsonb_extract_path(v_disease_params, 'l'||v_level)) as x(time integer, next_level integer);

  select x.job into v_job_id
  from jsonb_to_record(jsonb_extract_path(v_med_health, v_disease)) as x(job integer);

  delete from data.jobs where id = v_job_id;

  if v_time_to_next is not null then
    v_job_id := data.create_job(clock_timestamp() + (v_time_to_next::text || ' minutes')::interval, 
      'pallas_project.job_med_set_disease_level', 
      format('{"person_code": "%s", "disease": "%s", "level": %s}', v_person_code, v_disease, v_next_level)::jsonb);
  end if;

  if coalesce(v_message_text,'') <> '' then
    perform pp_utils.add_notification(v_person_id, v_message_text);
  end if;

  v_med_health := jsonb_set(v_med_health, 
    array[v_disease]::text[], 
    jsonb_strip_nulls(format('{"level": %s, "start": "%s", "diagnosted": %s, "job": %s}', v_level, pp_utils.format_date(clock_timestamp()), coalesce(v_diagnosted::text,'null'), coalesce(v_job_id::text, 'null'))::jsonb));

  v_changes := array[]::jsonb[];
    v_changes := array_append(v_changes, data.attribute_change2jsonb('med_health', v_med_health));
  if in_request_id is not null and in_client_id is not null then
      v_message_sent := data.change_current_object(in_client_id, 
                                                   in_request_id,
                                                   data.get_object_id(v_person_code || '_med_health'), 
                                                   to_jsonb(v_changes));

    if not v_message_sent then
     perform api_utils.create_ok_notification(in_client_id, in_request_id);
    end if;
  else
    perform data.change_object_and_notify(data.get_object_id(v_person_code || '_med_health'), 
                                          to_jsonb(v_changes),
                                          null);
  end if;
end;
$$
language plpgsql;
