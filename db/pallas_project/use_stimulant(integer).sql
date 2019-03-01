-- drop function pallas_project.use_stimulant(integer);

create or replace function pallas_project.use_stimulant(in_actor_id integer)
returns void
volatile
as
$$
declare
  v_orig_person_id integer := json.get_integer_opt(data.get_attribute_value(in_actor_id, 'system_person_original_id'), in_actor_id);
  v_orig_person_code text := data.get_object_code(v_orig_person_id);
  v_person_id integer; 

  v_message_text text := 'Мир как будто замедлился. Вы чувствуете необычайный подьём энергии и безграничность собственных возможностей.';

  v_med_stimulant jsonb := coalesce(data.get_attribute_value_for_update(v_orig_person_code || '_med_health', 'med_stimulant'), jsonb '{}');
  v_last_stimulant_job integer := json.get_integer_opt(json.get_object_opt(v_med_stimulant, 'last', jsonb '{}'), 'job', null);

  v_med_health jsonb := coalesce(data.get_attribute_value_for_update(v_orig_person_code || '_med_health', 'med_health'), jsonb '{}');
  v_addiction_level integer := json.get_integer_opt(json.get_object_opt(v_med_health, 'addiction', jsonb '{}'), 'level', 0);

  v_economic_cycle_number integer := data.get_integer_param('economic_cycle_number');
  v_stimulant_in_this_cycle integer := json.get_integer_opt(v_med_stimulant, 'cycle' || v_economic_cycle_number, 0);
  v_changes jsonb[];
begin
  -- Если стимулятор уже принят, то удаляем джоб его окончания
  if v_last_stimulant_job is not null then 
    delete from data.jobs where id = v_last_stimulant_job;
  end if;

-- Ставим, что принят стимулятор на персоны, отправляем уведомление всем дублям
  perform pp_utils.add_notification(v_orig_person_id, v_message_text);
   v_changes := array[]::jsonb[];
   v_changes := array_append(v_changes, data.attribute_change2jsonb('system_person_is_stimulant_used', jsonb 'true'));
  perform data.change_object_and_notify(v_orig_person_id, 
                                        to_jsonb(v_changes),
                                        null);
  for v_person_id in (select * from unnest(json.get_integer_array_opt(data.get_attribute_value(v_orig_person_id, 'system_person_doubles_id_list'), array[]::integer[]))) loop
    perform pp_utils.add_notification(v_person_id, v_message_text);
    perform data.change_object_and_notify(v_person_id,
                                          to_jsonb(v_changes),
                                          null);
  end loop;

  -- Вешаем джоб на полчаса, чтобы отменить действие
  v_last_stimulant_job := data.create_job(clock_timestamp() + '30 minutes'::interval, 
      'pallas_project.job_unuse_stimulant', 
      format('{"actor_id": %s}', v_orig_person_id)::jsonb);

  -- Если уже есть зависимость, то сдвигаем её на начало
  -- Если в этом цикле уже принимал, то начинаем зависимость
  if v_addiction_level > 0 or v_stimulant_in_this_cycle > 0 then
      perform pallas_project.act_med_set_disease_level(
        null, 
        null, 
        format('{"person_code": "%s", "disease": "%s", "level": %s}', v_orig_person_code, 'addiction', 1)::jsonb, 
        null, 
        null);
  end if;

  -- Сохраняем инфу о приёме стимулятора
  v_med_stimulant := jsonb_set(
    v_med_stimulant,
    array['last']::text[], 
    jsonb_strip_nulls(format('{"job": %s}', coalesce(v_last_stimulant_job::text, 'null'))::jsonb));
  v_med_stimulant := jsonb_set(
    v_med_stimulant,
    array['cycle' || v_economic_cycle_number]::text[], 
    format('%s', v_stimulant_in_this_cycle + 1)::jsonb);

  v_changes := array[]::jsonb[];
  v_changes := array_append(v_changes, data.attribute_change2jsonb('med_stimulant', v_med_stimulant));
  perform data.change_object_and_notify(data.get_object_id(v_orig_person_code || '_med_health'), 
                                        to_jsonb(v_changes),
                                        null);

end;
$$
language plpgsql;
