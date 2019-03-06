-- drop function pallas_project.use_sleg(integer);

create or replace function pallas_project.use_sleg(in_actor_id integer)
returns void
volatile
as
$$
declare
  v_orig_person_id integer := json.get_integer_opt(data.get_attribute_value(in_actor_id, 'system_person_original_id'), in_actor_id);
  v_orig_person_code text := data.get_object_code(v_orig_person_id);
  v_person_id integer; 

  v_message_text text;

  v_med_sleg jsonb ;
  v_last_sleg_job integer;

  v_med_stimulant jsonb := coalesce(data.get_attribute_value_for_share(v_orig_person_code || '_med_health', 'med_stimulant'), jsonb '{}');
  v_last_stimulant_job integer := json.get_integer_opt(json.get_object_opt(v_med_stimulant, 'last', jsonb '{}'), 'job', null);


  v_changes jsonb[];
  v_goood_effect integer := random.random_integer(1,3);
  v_person_doubles integer[] := json.get_integer_array_opt(data.get_attribute_value(v_orig_person_id, 'system_person_doubles_id_list'), array[]::integer[]);
begin

  if v_goood_effect = 1 then
    v_med_sleg := coalesce(data.get_attribute_value_for_update(v_orig_person_code || '_med_health', 'med_sleg'), jsonb '{}');
    v_last_sleg_job := json.get_integer_opt(json.get_object_opt(v_med_sleg, 'last', jsonb '{}'), 'job', null);
    -- Если есть джоб от приёма стимулятора, удаляем его
    if v_last_stimulant_job is not null then
      delete from data.jobs where id = v_last_stimulant_job;
    end if;
  -- Если слег уже принят c этим же эффектом, то удаляем джоб его окончания
    if v_last_sleg_job is not null then 
      delete from data.jobs where id = v_last_sleg_job;
    else
      perform data.change_object_and_notify(
        data.get_object_id('mine_person'),
        jsonb '[]' || data.attribute_change2jsonb('is_stimulant_used', jsonb 'true', v_orig_person_id));
    end if;
  -- Ставим, что принят стимулятор на персоны
    v_changes := array[]::jsonb[];
    v_changes := array_append(v_changes, data.attribute_change2jsonb('system_person_is_stimulant_used', jsonb 'true'));
    perform data.change_object_and_notify(v_orig_person_id, 
                                          to_jsonb(v_changes),
                                          null);
    for v_person_id in (select * from unnest(v_person_doubles)) loop
      perform data.change_object_and_notify(v_person_id,
                                            to_jsonb(v_changes),
                                            null);
    end loop;
    -- Вешаем джоб на час, чтобы отменить действие
    v_last_sleg_job := data.create_job(clock_timestamp() + '1 hour'::interval, 
      'pallas_project.job_unuse_stimulant', 
      format('{"actor_id": %s}', v_orig_person_id)::jsonb);
    v_message_text := 'Вы чувствуете, что выросли как профессионал. Ваша квалификация явно улучшилась. Эффект продлится 1 час';
  elsif v_goood_effect = 2 then
    v_message_text := 'Вы стали лучше считывать людей. Можете задать один любой вопрос любому человеку, а затем выяснить у мастера - правду ли ответили.';
  elsif v_goood_effect = 3 then
    v_message_text := 'Вы стали лучше управлять эмоциями и своим телом. В течение часа можете врать на допросе и игнорировать карточки.';
  end if;

  -- Уведомление о полезном эффекте
  perform pp_utils.add_notification(v_orig_person_id, v_message_text);
  for v_person_id in (select * from unnest(v_person_doubles)) loop
    perform pp_utils.add_notification(v_person_id, v_message_text);
  end loop;

  -- Cдвигаем зависимость на начало
  perform pallas_project.act_med_set_disease_level(
    null, 
    null, 
    format('{"person_code": "%s", "disease": "%s", "level": %s}', v_orig_person_code, 'sleg_addiction', 1)::jsonb, 
    null, 
    null);

  -- Запускаем побочные эффекты слега
  perform pallas_project.act_med_set_disease_level(
    null, 
    null, 
    format('{"person_code": "%s", "disease": "%s", "level": %s}', v_orig_person_code, 'sleg', 1)::jsonb, 
    null, 
    null);

  -- Сохраняем инфу о приёме слега
  if v_last_sleg_job is not null then
    v_med_sleg := jsonb_set(
      v_med_sleg,
      array['last']::text[], 
      jsonb_strip_nulls(format('{"job": %s}', coalesce(v_last_sleg_job::text, 'null'))::jsonb));
    v_changes := array[]::jsonb[];
    v_changes := array_append(v_changes, data.attribute_change2jsonb('med_sleg', v_med_sleg));
    perform data.change_object_and_notify(data.get_object_id(v_orig_person_code || '_med_health'), 
                                          to_jsonb(v_changes),
                                          null);
  end if;
end;
$$
language plpgsql;
