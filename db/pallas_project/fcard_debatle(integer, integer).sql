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
  v_debatle_status text;

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_debatle_person1_attribute_id integer := data.get_attribute_id('debatle_person1');
  v_debatle_person2_attribute_id integer := data.get_attribute_id('debatle_person2');
  v_debatle_judge_attribute_id integer := data.get_attribute_id('debatle_judge');
  v_debatle_my_vote_attribute_id integer := data.get_attribute_id('debatle_my_vote');
  v_debatle_person1_votes_attribute_id integer := data.get_attribute_id('debatle_person1_votes');
  v_debatle_person2_votes_attribute_id integer := data.get_attribute_id('debatle_person2_votes');

  v_system_debatle_person1_my_vote integer;
  v_system_debatle_person2_my_vote integer;

  v_system_debatle_person1_votes integer;
  v_system_debatle_person2_votes integer;

  v_new_title jsonb;
  v_new_person1 jsonb;
  v_new_person2 jsonb;
  v_new_judge jsonb;
  v_new_debatle_my_vote jsonb;
  v_new_debatle_person1_votes jsonb;
  v_new_debatle_person2_votes jsonb;
begin
  perform * from data.objects where id = in_object_id for update;

  v_debatle_theme := json.get_string_opt(data.get_attribute_value(in_object_id, 'system_debatle_theme'), null);
  v_debatle_status := json.get_string(data.get_attribute_value(in_object_id,'debatle_status'));
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

  --debatle_my_vote
  if v_debatle_status in ('vote', 'vote_over', 'closed') then
    v_system_debatle_person1_my_vote := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person1_my_vote', in_actor_id), 0);
    v_system_debatle_person2_my_vote := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person2_my_vote', in_actor_id), 0);

    if in_actor_id = v_person1_id 
      or in_actor_id = v_person2_id 
      or in_actor_id = v_judge_id 
      or pallas_project.is_in_group(in_actor_id, 'master') then
      v_new_debatle_my_vote := jsonb '"Вы не можете голосовать"';
    elsif v_system_debatle_person1_my_vote = 0 and v_system_debatle_person2_my_vote = 0 then
      if v_debatle_status = 'vote' then
        v_new_debatle_my_vote := jsonb '"Вы ещё не проголосовали"';
      else
        v_new_debatle_my_vote := jsonb '"Вы не голосовали"';
      end if;
    elsif v_system_debatle_person1_my_vote > 0 then
      v_new_debatle_my_vote := to_jsonb(format('Вы проголосовали за %s', json.get_string_opt(v_new_person1, 'зачинщика')));
    elsif v_system_debatle_person2_my_vote > 0 then
      v_new_debatle_my_vote := to_jsonb(format('Вы проголосовали за %s', json.get_string_opt(v_new_person2, 'оппонента')));
    end if;
    if coalesce(data.get_raw_attribute_value(in_object_id, v_debatle_my_vote_attribute_id, in_actor_id), jsonb '"~~~"') <> coalesce(v_new_debatle_my_vote, jsonb '"~~~"') then
      perform data.set_attribute_value(in_object_id, v_debatle_my_vote_attribute_id, v_new_debatle_my_vote, in_actor_id, in_actor_id);
    end if;

    v_system_debatle_person1_votes := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person1_votes'), 0);
    v_system_debatle_person2_votes := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person2_votes'), 0);



    v_new_debatle_person1_votes := to_jsonb(format('Количество голосов за %s: %s', json.get_string_opt(v_new_person1, 'зачинщика'), v_system_debatle_person1_votes));
    v_new_debatle_person2_votes := to_jsonb(format('Количество голосов за %s: %s', json.get_string_opt(v_new_person2, 'оппонента'), v_system_debatle_person2_votes));

    if coalesce(data.get_raw_attribute_value(in_object_id, v_debatle_person1_votes_attribute_id, in_actor_id), jsonb '"~~~"') <> coalesce(v_new_debatle_person1_votes, jsonb '"~~~"') then
      perform data.set_attribute_value(in_object_id, v_debatle_person1_votes_attribute_id, v_new_debatle_person1_votes, in_actor_id, in_actor_id);
    end if;
    if coalesce(data.get_raw_attribute_value(in_object_id, v_debatle_person2_votes_attribute_id, in_actor_id), jsonb '"~~~"') <> coalesce(v_new_debatle_person2_votes, jsonb '"~~~"') then
      perform data.set_attribute_value(in_object_id, v_debatle_person2_votes_attribute_id, v_new_debatle_person2_votes, in_actor_id, in_actor_id);
    end if;
  end if;
  --TODO 
  -- разобрать json с аудиториями и вывести списком через запятую
  -- посчитать стоимость голосования в зависимости от того, кто смотрит (астерам и марсианам по курсу коина, оон-овцам просто 1 коин)
  -- разобрать бонусы и штрафы.показывать только судье, мастерам и участникам (при этом участникам без кнопок изменения)

end;
$$
language plpgsql;
