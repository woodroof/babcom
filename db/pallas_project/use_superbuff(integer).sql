-- drop function pallas_project.use_superbuff(integer);

create or replace function pallas_project.use_superbuff(in_actor_id integer)
returns void
volatile
as
$$
declare
  v_orig_person_id integer := json.get_integer_opt(data.get_attribute_value(in_actor_id, 'system_person_original_id'), in_actor_id);
  v_orig_person_code text := data.get_object_code(v_orig_person_id);
  v_person_id integer; 

  v_message_text text;

  v_med_health jsonb := coalesce(data.get_attribute_value_for_update(v_orig_person_code || '_med_health', 'med_health'), jsonb '{}');
  v_wound jsonb := json.get_object_opt(v_med_health, 'wound', jsonb '{}');
  v_wound_level integer := json.get_integer_opt(v_wound, 'level', 0);
  v_wound_job integer := json.get_integer_opt(v_wound, 'job', null);
  v_changes jsonb[];
begin

  if v_wound_level in (1, 2) then
    if v_wound_job is not null then 
      delete from data.jobs where id = v_wound_job;
    end if;
    if v_wound_level= 1 then 
      v_message_text := 'Вы можете двигать раненой конечностью. Ничего не болит.';
    else
      v_message_text := 'Вы можете медленно передвигаться и разговаривать, не чувствуете боли.';
    end if;

    -- Отправляем уведомление всем дублям
    perform pp_utils.add_notification(v_orig_person_id, v_message_text);
    for v_person_id in (select * from unnest(json.get_integer_array_opt(data.get_attribute_value(v_orig_person_id, 'system_person_doubles_id_list'), array[]::integer[]))) loop
      perform pp_utils.add_notification(v_person_id, v_message_text);
    end loop;

    v_wound_job := data.create_job(clock_timestamp() + '5 minutes'::interval, 
       'pallas_project.job_med_set_disease_level', 
        format('{"person_code": "%s", "disease": "%s", "level": %s}', v_orig_person_code, 'wound', case when v_wound_level = 1 then 3 else 7 end  )::jsonb);

    v_med_health := jsonb_set(v_med_health, array['wound','job']::text[], to_jsonb(v_wound_job));
    v_changes := array[]::jsonb[];
    v_changes := array_append(v_changes, data.attribute_change2jsonb('med_health', v_med_health));
    perform data.change_object_and_notify(data.get_object_id(v_orig_person_code || '_med_health'), 
                                          to_jsonb(v_changes),
                                          null);
    end if;
end;
$$
language plpgsql;
