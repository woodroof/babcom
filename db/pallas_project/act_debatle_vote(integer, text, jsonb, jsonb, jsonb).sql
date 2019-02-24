-- drop function pallas_project.act_debatle_vote(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_vote(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_debatle_code text := json.get_string(in_params, 'debatle_code');
  v_voted_person text := json.get_string_opt(in_params, 'voted_person', '~~~');
  v_debatle_id  integer := data.get_object_id(v_debatle_code);
  v_actor_id  integer := data.get_active_actor_id(in_client_id);

  v_debatle_status text := json.get_string(data.get_attribute_value_for_share(v_debatle_id,'debatle_status'));
  v_system_debatle_person1_my_vote integer;
  v_system_debatle_person2_my_vote integer;
  v_system_debatle_person1_votes integer;
  v_system_debatle_person2_votes integer;
  v_person1_my_vote_new integer;
  v_person2_my_vote_new integer;
  v_person1_votes_new integer;
  v_person2_votes_new integer;
  v_nothing_changed boolean := false;

  v_debatle_person1_bonuses jsonb;
  v_debatle_person2_bonuses jsonb;
  v_person1 text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person1'), null);
  v_person2 text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person2'), null);

  v_person_opa_rating integer := json.get_integer_opt(data.get_raw_attribute_value_for_share(v_actor_id, 'person_opa_rating'), 0);
  v_economy_type text := json.get_string(data.get_attribute_value_for_share(v_actor_id, 'system_person_economy_type'));
  v_currency_attribute_id integer = data.get_attribute_id(case when v_economy_type = 'un' then 'system_person_coin' else 'system_money' end);
  v_current_sum bigint := json.get_bigint(data.get_attribute_value_for_update(v_actor_id, v_currency_attribute_id));
  v_price bigint;
  v_diff jsonb;

  v_changes jsonb[];

  v_is_master boolean := pp_utils.is_in_group(v_actor_id, 'master');
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;

  if v_debatle_status <> 'vote' then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Не время для голосования');
    return;
  end if;

  if v_voted_person not in ('instigator', 'opponent') or v_person1 is null or v_person2 is null then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Непонятно за кого проголосовали. Наверное что-то пошло не так. Обратитесь к мастеру.');
    return;
  end if;

  perform * from data.objects o where o.id = v_debatle_id for update;

  v_system_debatle_person1_my_vote := json.get_integer_opt(data.get_raw_attribute_value_for_update(v_debatle_id, 'system_debatle_person1_my_vote', v_actor_id), 0);
  v_system_debatle_person2_my_vote := json.get_integer_opt(data.get_raw_attribute_value_for_update(v_debatle_id, 'system_debatle_person2_my_vote', v_actor_id), 0);

  assert v_system_debatle_person1_my_vote >= 0;
  assert v_system_debatle_person2_my_vote >= 0;

  if v_voted_person = 'instigator' then 
    if v_system_debatle_person1_my_vote > 0 then 
      v_nothing_changed := true;
    else
      v_person1_my_vote_new := v_person_opa_rating;
      v_person2_my_vote_new := 0;
    end if;
  elsif v_voted_person = 'opponent' then 
    if v_system_debatle_person2_my_vote > 0 then 
      v_nothing_changed := true;
    else
      v_person2_my_vote_new := v_person_opa_rating;
      v_person1_my_vote_new := 0;
    end if;
  end if;

  if not v_nothing_changed then
    v_system_debatle_person1_votes := json.get_integer_opt(data.get_attribute_value_for_update(v_debatle_id, 'system_debatle_person1_votes'), 0);
    v_system_debatle_person2_votes := json.get_integer_opt(data.get_attribute_value_for_update(v_debatle_id, 'system_debatle_person2_votes'), 0);
    v_person1_votes_new := v_system_debatle_person1_votes + v_person1_my_vote_new - v_system_debatle_person1_my_vote;
    v_person2_votes_new := v_system_debatle_person2_votes + v_person2_my_vote_new - v_system_debatle_person2_my_vote;

    if v_system_debatle_person1_my_vote <> v_person1_my_vote_new then 
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person1_my_vote', to_jsonb(v_person1_my_vote_new), v_actor_id));
    end if;
    if v_system_debatle_person2_my_vote <> v_person2_my_vote_new then 
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person2_my_vote', to_jsonb(v_person2_my_vote_new), v_actor_id));
    end if;
    if v_person1_my_vote_new > 0 then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_my_vote', 
        to_jsonb('Вы проголосовали за '|| pp_utils.link(v_person1)), v_actor_id));
    elsif v_person2_my_vote_new >0 then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_my_vote', 
        to_jsonb('Вы проголосовали за '|| pp_utils.link(v_person2)), v_actor_id));
    end if;

    -- Возьмём плату за голосование
    if v_system_debatle_person1_my_vote + v_system_debatle_person2_my_vote = 0 and v_person1_my_vote_new + v_person2_my_vote_new>0 then
      v_price := 1;
      if v_economy_type = 'un' then
        v_diff := pallas_project.change_coins(v_actor_id, (v_current_sum - v_price)::integer, v_actor_id, 'Debatle voiting');
      else
        v_price := v_price * data.get_integer_param('coin_price');
        v_diff := pallas_project.change_money(v_actor_id, v_current_sum - v_price, v_actor_id, 'Debatle voiting');
        perform pallas_project.create_transaction(
          v_actor_id,
          format(
            'Плата за голосование в дебатле "%s"',
            json.get_string(data.get_raw_attribute_value(v_debatle_id, 'title'))),
          -v_price,
          v_current_sum - v_price,
          null,
          null,
          v_actor_id);
      end if;
      perform data.process_diffs_and_notify(v_diff);
    end if;

    if v_system_debatle_person1_votes <> v_person1_votes_new then 
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person1_votes', to_jsonb(v_person1_votes_new)));
      v_debatle_person1_bonuses := data.get_attribute_value_for_share(v_debatle_id, 'debatle_person1_bonuses');
      v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person1_votes', 
        to_jsonb(pallas_project.get_debatle_person_votes_text(v_person1, v_person1_votes_new, v_debatle_person1_bonuses))));
    end if;
    if v_system_debatle_person2_votes <> v_person2_votes_new then 
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person2_votes', to_jsonb(v_person2_votes_new)));
      v_debatle_person2_bonuses := data.get_attribute_value_for_share(v_debatle_id, 'debatle_person2_bonuses');
      v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person2_votes', 
        to_jsonb(pallas_project.get_debatle_person_votes_text(v_person2, v_person2_votes_new, v_debatle_person2_bonuses))));

    end if;
    if array_length(v_changes, 1) > 0 then
      v_message_sent := data.change_current_object(in_client_id, 
                                                   in_request_id,
                                                   v_debatle_id, 
                                                   to_jsonb(v_changes));
    end if;
  end if;

  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language plpgsql;
