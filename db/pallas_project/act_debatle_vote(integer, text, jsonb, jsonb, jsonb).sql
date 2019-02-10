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

  v_debatle_status text := json.get_string(data.get_attribute_value(v_debatle_id,'debatle_status'));
  v_system_debatle_person1 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person1'), -1);
  v_system_debatle_person2 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person2'), -1);
  v_system_debatle_person1_my_vote integer;
  v_system_debatle_person2_my_vote integer;
  v_system_debatle_person1_votes integer;
  v_system_debatle_person2_votes integer;
  v_person1_my_vote_new integer;
  v_person2_my_vote_new integer;
  v_person1_votes_new integer;
  v_person2_votes_new integer;
  v_nothing_changed boolean := false;

  v_changes jsonb[];

  v_is_master boolean := pp_util.is_in_group(v_actor_id, 'master');
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;

  if v_debatle_status <> 'vote' then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Не время для голосования');
    return;
  end if;

  if v_voted_person not in ('instigator', 'opponent') then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Непонятно за кого проголосовали. Наверное что-то пошло не так. Обратитесь к мастеру.');
    return;
  end if;

  perform * from data.objects o where o.id = v_debatle_id for update;

  v_system_debatle_person1_my_vote := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person1_my_vote', v_actor_id), 0);
  v_system_debatle_person2_my_vote := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person2_my_vote', v_actor_id), 0);

  assert v_system_debatle_person1_my_vote >= 0;
  assert v_system_debatle_person2_my_vote >= 0;

  if v_voted_person = 'instigator' then 
    if v_system_debatle_person1_my_vote > 0 then 
      v_nothing_changed := true;
    else
      v_person1_my_vote_new := 1;
      v_person2_my_vote_new := 0;
    end if;
  elsif v_voted_person = 'opponent' then 
    if v_system_debatle_person2_my_vote > 0 then 
      v_nothing_changed := true;
    else
      v_person2_my_vote_new := 1;
      v_person1_my_vote_new := 0;
    end if;
  end if;

  if not v_nothing_changed then
    v_system_debatle_person1_votes := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person1_votes'), 0);
    v_system_debatle_person2_votes := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person2_votes'), 0);
    v_person1_votes_new := v_system_debatle_person1_votes + v_person1_my_vote_new - v_system_debatle_person1_my_vote;
    v_person2_votes_new := v_system_debatle_person2_votes + v_person2_my_vote_new - v_system_debatle_person2_my_vote;

    if v_system_debatle_person1_my_vote <> v_person1_my_vote_new then 
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person1_my_vote', to_jsonb(v_person1_my_vote_new), v_actor_id));
    end if;
    if v_system_debatle_person2_my_vote <> v_person2_my_vote_new then 
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person2_my_vote', to_jsonb(v_person2_my_vote_new), v_actor_id));
    end if;
    if v_system_debatle_person1_votes <> v_person1_votes_new then 
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person1_votes', to_jsonb(v_person1_votes_new)));
    end if;
    if v_system_debatle_person2_votes <> v_person2_votes_new then 
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person2_votes', to_jsonb(v_person2_votes_new)));
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
