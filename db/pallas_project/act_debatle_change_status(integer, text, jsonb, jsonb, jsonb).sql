-- drop function pallas_project.act_debatle_change_status(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_change_status(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_debatle_code text := json.get_string(in_params, 'debatle_code');
  v_new_status text := json.get_string(in_params, 'new_status');
  v_debatle_id integer := data.get_object_id(v_debatle_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_actor_code text :=data.get_object_code(v_actor_id);

  v_is_master boolean := pp_utils.is_in_group(v_actor_id, 'master');
  v_master_group_id integer:= data.get_object_id('master'); 

  v_debatle_status text;
  v_debatle_person1 text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person1'), null);
  v_debatle_person2 text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person2'), null);
  v_debatle_judge text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_judge'), null);
  v_debatle_title text := json.get_string_opt(data.get_raw_attribute_value_for_share(v_debatle_id, 'title'), '');

  v_debatle_person1_id integer := data.get_object_id_opt(v_debatle_person1);
  v_debatle_person2_id integer := data.get_object_id_opt(v_debatle_person2);
  v_debatle_judge_id integer := data.get_object_id_opt(v_debatle_judge);

  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_system_debatle_is_confirmed_presence_attribute_id integer := data.get_attribute_id('system_debatle_is_confirmed_presence');
  v_debatle_my_vote_attribute_id integer := data.get_attribute_id('debatle_my_vote');

  v_content text[];
  v_new_content text[];
  v_debatles_new_id integer := data.get_object_id('debatles_new');
  v_debatles_future_id integer := data.get_object_id('debatles_future');
  v_debatles_current_id integer := data.get_object_id('debatles_current');
  v_debatles_closed_id integer := data.get_object_id('debatles_closed');

  v_changes jsonb[];
  v_message_sent boolean;

  v_audience integer[] := pallas_project.get_groups_members(json.get_string_array_opt(data.get_attribute_value_for_share(v_debatle_id, 'system_debatle_target_audience'), array[]::text[]));
  v_person_id integer;
  v_debatle_my_vote text;
begin
  assert in_request_id is not null;

  v_debatle_status := json.get_string_opt(data.get_attribute_value_for_update(v_debatle_id, 'debatle_status'), '~~~');

  if v_new_status = 'new' and v_debatle_status = 'draft' and (v_is_master or v_actor_code = v_debatle_person1) then
    -- добавляем в неподтверждённые
    perform pp_utils.list_prepend_and_notify(v_debatles_new_id, v_debatle_code, null, v_actor_id);
    -- Отправляем мастерам в чат уведомление 
    perform pallas_project.send_to_master_chat('Создан новый дебатл', v_debatle_code);

  elsif v_new_status = 'future' and v_debatle_status = 'new' and v_is_master then
    if v_debatle_person1 is null or v_debatle_person2 is null then
      perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Зачинщик и оппонент дебатла должны быть заполнены');
      return;
    end if;
    if v_audience is null or array_length(v_audience, 1) = 0 then
      perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Целевая аудитория должна быть заполнена');
      return;
    end if;
    -- удаляем из неподтверждённых, добавляем в будущие
    perform pp_utils.list_remove_and_notify(v_debatles_new_id, v_debatle_code, null);
    perform pp_utils.list_prepend_and_notify(v_debatles_future_id, v_debatle_code, null, v_actor_id);
    -- Рассылаем уведомления
    for v_person_id in (select * from unnest(v_audience)
                        where unnest not in (coalesce(v_debatle_person1_id, -1), coalesce(v_debatle_person2_id, -1), coalesce(v_debatle_judge_id, -1))) loop
      perform pp_utils.add_notification(v_person_id, 'Вы приглашены на дебатл ' || v_debatle_title|| '. Найдите его в разделе будущих дебатлов, чтобы узнать подробности и обсудить событие', v_debatle_id);
    end loop;
    if v_debatle_person1_id is not null then
      perform pp_utils.add_notification(v_debatle_person1_id, 'Вы приглашены на дебатл ' || v_debatle_title|| ' в качестве зачинщика. Дебатлы, в которых вы участвуете, находятся в разделе Мои дебатлы', v_debatle_id);
    end if;
    if v_debatle_person2_id is not null then
      perform pp_utils.add_notification(v_debatle_person2_id, 'Вы приглашены на дебатл ' || v_debatle_title|| ' в качестве оппонента. Дебатлы, в которых вы участвуете, находятся в разделе Мои дебатлы', v_debatle_id);
    end if;
    if v_debatle_judge_id is not null then
      perform pp_utils.add_notification(v_debatle_judge_id, 'Вы приглашены на дебатл ' || v_debatle_title|| ' в качестве судьи. Дебатлы, в которых вы участвуете, находятся в разделе Мои дебатлы', v_debatle_id);
    end if;

  elsif v_new_status = 'vote' and v_debatle_status = 'future' and (v_is_master or v_debatle_judge = v_actor_code) then
    if v_debatle_judge is null or v_debatle_person1 is null or v_debatle_person2 is null then
      perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Попросите мастера внести недостающих участников дебатла прежде чем начать');
      return;
    end if;
  -- удаляем из будущих, добавляем в текущие
    perform pp_utils.list_remove_and_notify(v_debatles_future_id, v_debatle_code, null);
    perform pp_utils.list_prepend_and_notify(v_debatles_current_id, v_debatle_code, null, v_actor_id);

  elsif v_new_status = 'vote_over' and v_debatle_status = 'vote' and (v_is_master or v_debatle_judge = v_actor_code) then
    null; -- не надо переставлять ничего по группам

  elsif v_new_status = 'closed' and v_debatle_status = 'vote_over' and (v_is_master or v_debatle_judge = v_actor_code) then
    -- удаляем из текущих, добавляем в завершённые
    perform pp_utils.list_remove_and_notify(v_debatles_current_id, v_debatle_code, null);
    perform pp_utils.list_prepend_and_notify(v_debatles_closed_id, v_debatle_code, null, v_actor_id);
  -- TODO тут возможно надо ещё менять какие-то статусы участникам дебатла

  elsif v_new_status = 'deleted' and (v_is_master or v_debatle_person1 = v_actor_code and v_debatle_status = 'draft') then
    -- удаляем
    -- из неподтверждённых
    -- из будущих
    -- из текущих
    -- из закрытых
    if v_debatle_status = 'new' then
      perform pp_utils.list_remove_and_notify(v_debatles_new_id, v_debatle_code, null);
    elsif v_debatle_status = 'future' then
      perform pp_utils.list_remove_and_notify(v_debatles_future_id, v_debatle_code, null);
    elsif v_debatle_status in ('vote', 'vote_over') then
      perform pp_utils.list_remove_and_notify(v_debatles_current_id, v_debatle_code, null);
    elsif v_debatle_status = 'closed' then
      perform pp_utils.list_remove_and_notify(v_debatles_closed_id, v_debatle_code, null);
    end if;

    -- Рассылаем уведомления 
    if v_debatle_status in ('future', 'vote') then
      for v_person_id in (select * from unnest(v_audience)
                          where unnest not in (coalesce(v_debatle_person1_id, -1), coalesce(v_debatle_person2_id, -1), coalesce(v_debatle_judge_id, -1))) loop
        perform pp_utils.add_notification(v_person_id, 'Дебатл ' || v_debatle_title|| ' был отменён');
      end loop;
      if v_debatle_person1_id is not null then
        perform pp_utils.add_notification(v_debatle_person1_id, 'Дебатл ' || v_debatle_title|| ' был отменён');
      end if;
      if v_debatle_person2_id is not null then
        perform pp_utils.add_notification(v_debatle_person2_id, 'Дебатл ' || v_debatle_title|| ' был отменён');
      end if;
      if v_debatle_judge_id is not null then
        perform pp_utils.add_notification(v_debatle_judge_id, 'Дебатл ' || v_debatle_title|| ' был отменён');
      end if;
    end if;

  else
     perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Ошибка',
      'Некорректное изменение статуса дебатла'); 
    return;
  end if;

  -- если статус поменялся на future, то надо добавить видимость второму участнику, судье и аудитории, плюс создать чатик
  if v_new_status = 'future' then
    if v_debatle_person2 is not null then 
     v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', jsonb 'true', data.get_object_id(v_debatle_person2)));
    end if;
    if v_debatle_judge is not null then 
     v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', jsonb 'true', data.get_object_id(v_debatle_judge)));
    end if;
    perform pallas_project.create_chat(v_debatle_code || '_chat',
                   jsonb_build_object(
                   'content', jsonb '[]',
                   'title', 'Обсуждение дебатла ' || json.get_string_opt(data.get_raw_attribute_value_for_share(v_debatle_id, 'title'), ''),
                   'system_chat_is_renamed', true,
                   'system_chat_parent_list', 'chats',
                   'system_chat_can_invite', false,
                   'system_chat_can_leave', false,
                   'system_chat_can_rename', false,
                   'system_chat_cant_see_members', true,
                   'system_chat_length', 0
                 ));
  elsif v_new_status = 'vote' then
  -- Если стaтус поменялся на vote надо добавить всем инфу о ходе голосования
    for v_person_id in (select * from unnest(pallas_project.get_debatle_spectators(v_debatle_id))) loop
      if json.get_boolean_opt(data.get_raw_attribute_value_for_share(v_debatle_id, v_system_debatle_is_confirmed_presence_attribute_id, v_person_id), false) then
        v_debatle_my_vote := 'Вы не голосовали';
      else
        v_debatle_my_vote := 'Отсканируйте QR-код на месте дебатла, чтобы голосовать';
      end if;
      v_changes := array_append(v_changes, data.attribute_change2jsonb(v_debatle_my_vote_attribute_id, to_jsonb(v_debatle_my_vote), v_person_id));
    end loop;
    v_debatle_my_vote := 'Вы не можете голосовать';
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_debatle_my_vote_attribute_id, to_jsonb(v_debatle_my_vote), v_debatle_person1_id));
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_debatle_my_vote_attribute_id, to_jsonb(v_debatle_my_vote), v_debatle_person2_id));
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_debatle_my_vote_attribute_id, to_jsonb(v_debatle_my_vote), v_debatle_judge_id));
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_debatle_my_vote_attribute_id, to_jsonb(v_debatle_my_vote), v_master_group_id));
  elsif v_new_status = 'closed' then
    -- При закрытии дебатла надо добавить единицу статуса победителю и забрать у проигравшего
    declare
      v_person1_opa_rating integer := json.get_integer_opt(data.get_raw_attribute_value_for_update(v_debatle_person1_id, 'person_opa_rating'), 0);
      v_person2_opa_rating integer := json.get_integer_opt(data.get_raw_attribute_value_for_update(v_debatle_person2_id, 'person_opa_rating'), 0);
      v_debatle_person1_bonuses jsonb := data.get_attribute_value_for_share(v_debatle_id, 'debatle_person1_bonuses');
      v_debatle_person2_bonuses jsonb := data.get_attribute_value_for_share(v_debatle_id, 'debatle_person2_bonuses');
      v_system_debatle_person1_votes integer := json.get_integer_opt(data.get_attribute_value_for_share(v_debatle_id, 'system_debatle_person1_votes'), 0);
      v_system_debatle_person2_votes integer := json.get_integer_opt(data.get_attribute_value_for_share(v_debatle_id, 'system_debatle_person2_votes'), 0);
      v_person1_votes integer;
      v_person2_votes integer;
      v_debatle_result text;
    begin
      select coalesce(sum(x.votes), 0) into v_person1_votes from jsonb_to_recordset(coalesce(v_debatle_person1_bonuses, jsonb '[]')) as x(code text, name text, votes int);
      select coalesce(sum(x.votes), 0) into v_person2_votes from jsonb_to_recordset(coalesce(v_debatle_person2_bonuses, jsonb '[]')) as x(code text, name text, votes int);
      v_person1_votes := v_person1_votes + v_system_debatle_person1_votes;
      v_person2_votes := v_person2_votes + v_system_debatle_person2_votes;
      if v_person1_votes > v_person2_votes then
        v_person1_opa_rating := v_person1_opa_rating + 1;
        if v_person2_opa_rating > 1 then
          v_person1_opa_rating := v_person1_opa_rating - 1;
        end if;
        v_debatle_result := 'Дебатл ' || v_debatle_title || ' завершился победой ' || pp_utils.link(v_debatle_person1);
      elsif v_person1_votes < v_person2_votes then
        v_person2_opa_rating := v_person2_opa_rating + 1;
        if v_person1_opa_rating > 1 then
          v_person1_opa_rating := v_person1_opa_rating - 1;
        end if;
        v_debatle_result := 'Дебатл ' || v_debatle_title || ' завершился победой ' || pp_utils.link(v_debatle_person2);
      else
        v_debatle_result := 'Дебатл ' || v_debatle_title || ' завершился. Счёт голосов равный. Победитель не определён';
      end if;
      perform data.change_object_and_notify(v_debatle_person1_id,
                                            jsonb_build_array(data.attribute_change2jsonb('person_opa_rating', to_jsonb(v_person1_opa_rating))), v_actor_id);
      perform data.change_object_and_notify(v_debatle_person2_id,
                                            jsonb_build_array(data.attribute_change2jsonb('person_opa_rating', to_jsonb(v_person2_opa_rating))), v_actor_id);
      for v_person_id in (select * from unnest(pallas_project.get_debatle_spectators(v_debatle_id))) loop
        perform pp_utils.add_notification(v_person_id, v_debatle_result, v_debatle_id);
      end loop;
      perform pp_utils.add_notification(v_debatle_person1_id, v_debatle_result, v_debatle_id);
      perform pp_utils.add_notification(v_debatle_person2_id, v_debatle_result, v_debatle_id);
      perform pp_utils.add_notification(v_debatle_judge_id, v_debatle_result, v_debatle_id);
    end;
  end if;

  v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_status', to_jsonb(v_new_status)));
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               v_debatle_id, 
                                               to_jsonb(v_changes));
  if not v_message_sent then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
