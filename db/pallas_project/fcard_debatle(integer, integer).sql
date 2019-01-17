-- drop function pallas_project.fcard_debatle(integer, integer);

create or replace function pallas_project.fcard_debatle(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_value jsonb;
  v_person1_id integer;
  v_person2_id integer;
  v_judge_id integer;
  v_is_master boolean;
  v_changes jsonb[];
begin
  perform * from data.objects where id = in_object_id for update;

  v_person1_id := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person1'), null);
  v_person2_id := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person2'), null);
  v_judge_id := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_judge'), null);

  v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person1', null, data.get_attribute_value(v_person1_id, 'title', in_actor_id)));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person2', null, data.get_attribute_value(v_person2_id, 'title', in_actor_id)));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_judge', null, data.get_attribute_value(v_judge_id, 'title', in_actor_id)));

  v_is_master := json.get_boolean(data.get_attribute_value(in_actor_id, 'person_is_master'));

  --TODO 
  -- разобрать json с аудиториями и вывести списком через запятую
  -- посчитать стоимость голосования в зависимости от того, кто смотрит (астерам и марсианам по курсу коина, оон-овцам просто 1 коин)
  -- выводить количество голосов только когда статус Голосование завершено
  -- разобрать бонусы и штрафы.показывать только судье, мастерам и участникам (при этом участникам без кнопок изменения)

if v_is_master or in_actor_id in (v_person1_id, v_person2_id, v_judge_id) then
null;
/*    v_value := data.get_attribute_value(in_object_id, 'system_money');
    if json.get_bigint(v_value) is not null then
      perform data.set_attribute_value(in_object_id, 'money', v_value, in_actor_id);
    end if;
*/
    end if;

  perform data.change_object(in_object_id, to_jsonb(v_changes), in_actor_id);
end;
$$
language 'plpgsql';
