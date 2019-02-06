-- drop function pallas_project.actgenerator_debatle(integer, integer);

create or replace function pallas_project.actgenerator_debatle(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_person1_id integer;
  v_person2_id integer;
  v_judge_id integer;
  v_is_master boolean;
  v_debatle_code text;
  v_debatle_status text;
  v_system_debatle_theme_attribute_id integer := data.get_attribute_id('system_debatle_theme');
  v_subtitle_attribute_id integer := data.get_attribute_id('subtitle');
  v_chat_id integer;
  v_chat_length integer;
  v_chat_unread integer;
begin
  assert in_actor_id is not null;

  v_is_master := pp_utils.is_in_group(in_actor_id, 'master');
  v_debatle_code := data.get_object_code(in_object_id);
  v_person1_id := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person1'), null);
  v_person2_id := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person2'), null);
  v_judge_id := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_judge'), null);
  v_debatle_status := json.get_string_opt(data.get_attribute_value(in_object_id, 'debatle_status'), null);

  if v_is_master then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_instigator": {"code": "debatle_change_person", "name": "Изменить зачинщика", "disabled": false, '||
                '"params": {"debatle_code": "%s", "edited_person": "instigator"}}',
                v_debatle_code);
  end if;

  if v_is_master or in_actor_id = v_person1_id and v_debatle_status in ('draft') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_opponent": {"code": "debatle_change_person", "name": "Изменить оппонента", "disabled": false, '||
                '"params": {"debatle_code": "%s", "edited_person": "opponent"}}',
                v_debatle_code);
  end if;

  if v_is_master then
      v_actions_list := v_actions_list || 
        format(', "debatle_change_judge": {"code": "debatle_change_person", "name": "Изменить судью", "disabled": false, '||
                '"params": {"debatle_code": "%s", "edited_person": "judge"}}',
                v_debatle_code);
  end if;

  if v_is_master or in_actor_id = v_person1_id and v_debatle_status in ('draft') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_theme": {"code": "debatle_change_theme", "name": "Изменить тему", "disabled": false, '||
                '"params": {"debatle_code": "%s"}, "user_params": [{"code": "title", "description": "Введите тему дебатла", "type": "string", "default_value": "%s" }]}',
                v_debatle_code,
                json.get_string_opt(data.get_raw_attribute_value(in_object_id, v_system_debatle_theme_attribute_id, null),''));
  end if;

  if v_is_master then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_subtitle": {"code": "debatle_change_subtitle", "name": "Изменить место и время", "disabled": false, '||
                '"params": {"debatle_code": "%s"}, "user_params": [{"code": "subtitle", "description": "Введите место и время текстом", "type": "string", "default_value": "%s" }]}',
                v_debatle_code,
                json.get_string_opt(data.get_raw_attribute_value(in_object_id, v_subtitle_attribute_id, null),''));
  end if;

  if (v_is_master or in_actor_id = v_person1_id) and v_debatle_status in ('draft') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_status_new": {"code": "debatle_change_status", "name": "Отправить мастеру на подтверждение", "disabled": false, '||
                '"params": {"debatle_code": "%s", "new_status": "new"}}',
                v_debatle_code);
  end if;

  if v_is_master and v_debatle_status in ('new') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_status_future": {"code": "debatle_change_status", "name": "Подтвердить", "disabled": false, '||
                '"params": {"debatle_code": "%s", "new_status": "future"}}',
                v_debatle_code);
  end if;

  if (v_is_master or in_actor_id = v_judge_id) and v_debatle_status in ('future') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_status_vote": {"code": "debatle_change_status", "name": "Начать дебатл", "disabled": false, '||
                '"params": {"debatle_code": "%s", "new_status": "vote"}}',
                v_debatle_code);
  end if;

  if (v_is_master or in_actor_id = v_judge_id) and v_debatle_status in ('vote') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_status_vote_over": {"code": "debatle_change_status", "name": "Завершить голосование", "disabled": false, '||
                '"params": {"debatle_code": "%s", "new_status": "vote_over"}}',
                v_debatle_code);
  end if;

  if (v_is_master or in_actor_id = v_judge_id) and v_debatle_status in ('vote_over') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_status_closed": {"code": "debatle_change_status", "name": "Завершить дебатл", "disabled": false, '||
                '"params": {"debatle_code": "%s", "new_status": "closed"}}',
                v_debatle_code);
  end if;

  if v_is_master and v_debatle_status not in ('deleted') or in_actor_id = v_person1_id and v_debatle_status in ('draft') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_status_deleted": {"code": "debatle_change_status", "name": "Удалить", "disabled": false, '||
                '"params": {"debatle_code": "%s", "new_status": "deleted"}}',
                v_debatle_code);
  end if;

  if v_debatle_status in ('vote') 
    and not v_is_master
    and v_person1_id is not null
    and v_person2_id is not null
    and v_judge_id is not null
    and in_actor_id not in (v_person1_id, v_person2_id, v_judge_id) then
      v_actions_list := v_actions_list || 
        format(', "debatle_vote_person1": {"code": "debatle_vote", "name": "Голосовать за %s", "disabled": %s, '||
                '"params": {"debatle_code": "%s", "voted_person": "instigator"}}',
                json.get_string_opt(data.get_attribute_value(v_person1_id, 'title', in_actor_id), ''),
                case when json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person1_my_vote', in_actor_id), 0) > 0 then 'true' else 'false' end,
                v_debatle_code);
     v_actions_list := v_actions_list || 
        format(', "debatle_vote_person2": {"code": "debatle_vote", "name": "Голосовать за %s", "disabled": %s, '||
                '"params": {"debatle_code": "%s", "voted_person": "opponent"}}',
                json.get_string_opt(data.get_attribute_value(v_person2_id, 'title', in_actor_id), ''),
                case when json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person2_my_vote', in_actor_id), 0) > 0 then 'true' else 'false' end,
                v_debatle_code);
  end if;

  if v_debatle_status in ('vote', 'vote_over') and in_actor_id = v_judge_id or
   v_debatle_status in ('future', 'vote', 'vote_over', 'closed') and v_is_master then
      v_actions_list := v_actions_list || 
        format(', "debatle_change_bonuses1": {"code": "debatle_change_bonuses", "name": "Оштрафовать или наградить %s", "disabled": false, '||
                '"params": {"debatle_code": "%s", "judged_person": "instigator"}}',
                json.get_string_opt(data.get_attribute_value(v_person1_id, 'title', in_actor_id), ''),
                v_debatle_code);
     v_actions_list := v_actions_list || 
        format(', "debatle_change_bonuses2": {"code": "debatle_change_bonuses", "name": "Оштрафовать или наградить %s", "disabled": false, '||
                '"params": {"debatle_code": "%s", "judged_person": "opponent"}}',
                json.get_string_opt(data.get_attribute_value(v_person2_id, 'title', in_actor_id), ''),
                v_debatle_code);
  end if;

  if v_debatle_status in ('future', 'vote', 'vote_over', 'closed') then
    v_chat_id := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_chat_id', in_actor_id), null);
    if v_chat_id is not null then
      v_chat_length := json.get_integer_opt(data.get_attribute_value(v_chat_id, 'system_chat_length'), 0);
      v_chat_unread := json.get_integer_opt(data.get_attribute_value(v_chat_id, 'chat_unread_messages', in_actor_id), null);
      v_actions_list := v_actions_list || 
          format(', "debatle_chat": {"code": "chat_enter", "name": "Обсудить%s", "disabled": false, '||
                  '"params": {"object_code": "%s"}}',
                  case when v_chat_length = 0 then ''
                  when v_chat_length > 0 and v_chat_unread is null then ' (' || v_chat_length || ')'
                  else ' (' || v_chat_length || ', непрочитанных ' || v_chat_unread || ')' 
                  end,
                  v_debatle_code);
    end if;
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
