-- drop function pallas_project.fcard_debatle(integer, integer);

create or replace function pallas_project.fcard_debatle(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_person1_id integer;
  v_person2_id integer;
  v_judge_id integer;
  v_debatle_theme text;

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_debatle_person1_attribute_id integer := data.get_attribute_id('debatle_person1');
  v_debatle_person2_attribute_id integer := data.get_attribute_id('debatle_person2');
  v_debatle_judge_attribute_id integer := data.get_attribute_id('debatle_judge');

  v_new_title jsonb;
  v_new_person1 jsonb;
  v_new_person2 jsonb;
  v_new_judge jsonb;
begin
  perform * from data.objects where id = in_object_id for update;

  v_debatle_theme := json.get_string_opt(data.get_attribute_value(in_object_id, 'system_debatle_theme'), null);
  v_person1_id := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person1'), null);
  v_person2_id := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person2'), null);
  v_judge_id := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_judge'), null);

  v_new_title := to_jsonb(format('Дебатл: %s', v_debatle_theme));
  if coalesce(data.get_raw_attribute_value(in_object_id, v_title_attribute_id, in_actor_id), jsonb '"~~~"') <> coalesce(v_new_title, jsonb '"~~~"') then
    perform data.set_attribute_value(in_object_id, v_title_attribute_id, v_new_title, in_actor_id, in_actor_id);
  end if;

  if v_person1_id is not null then
    v_new_person1 := data.get_attribute_value(v_person1_id, v_title_attribute_id, in_actor_id);
  end if;
  if coalesce(data.get_raw_attribute_value(in_object_id, v_debatle_person1_attribute_id, null), jsonb '"~~~"') <> coalesce(v_new_person1, jsonb '"~~~"') then
    perform data.set_attribute_value(in_object_id, v_debatle_person1_attribute_id, v_new_person1, null, in_actor_id);
  end if;

  if v_person2_id is not null then
    v_new_person2 := data.get_attribute_value(v_person2_id, v_title_attribute_id, in_actor_id);
  end if;
  if coalesce(data.get_raw_attribute_value(in_object_id, v_debatle_person2_attribute_id, null), jsonb '"~~~"') <> coalesce(v_new_person2, jsonb '"~~~"') then
    perform data.set_attribute_value(in_object_id, v_debatle_person2_attribute_id, v_new_person2, null, in_actor_id);
  end if;

  if v_judge_id is not null then
    v_new_judge := data.get_attribute_value(v_judge_id, v_title_attribute_id, in_actor_id);
  end if;
  if coalesce(data.get_raw_attribute_value(in_object_id, v_debatle_judge_attribute_id, null), jsonb '"~~~"') <> coalesce(v_new_judge, jsonb '"~~~"') then
    perform data.set_attribute_value(in_object_id, v_debatle_judge_attribute_id, v_new_judge, null, in_actor_id);
  end if;


  --TODO 
  -- разобрать json с аудиториями и вывести списком через запятую
  -- посчитать стоимость голосования в зависимости от того, кто смотрит (астерам и марсианам по курсу коина, оон-овцам просто 1 коин)
  -- выводить количество голосов только когда статус Голосование завершено
  -- разобрать бонусы и штрафы.показывать только судье, мастерам и участникам (при этом участникам без кнопок изменения)

end;
$$
language plpgsql;
