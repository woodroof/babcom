-- drop function pallas_project.actgenerator_claim(integer, integer);

create or replace function pallas_project.actgenerator_claim(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_actor_code text := data.get_object_code(in_actor_id);
  v_is_master boolean;
  v_is_judge boolean;
  v_claim_code text;
  v_claim_author text := json.get_string(data.get_attribute_value(in_object_id, 'claim_author'));
  v_claim_plaintiff text := json.get_string(data.get_attribute_value(in_object_id, 'claim_plaintiff'));
  v_claim_defendant text := json.get_string_opt(data.get_attribute_value_for_share(in_object_id, 'claim_defendant'), null);
  v_claim_status text := json.get_string(data.get_attribute_value_for_share(in_object_id, 'claim_status'));
  v_claim_to_asj boolean := json.get_boolean_opt(data.get_attribute_value_for_share(in_object_id, 'system_claim_to_asj'), false);

  v_claim_plaintiff_type text;
  v_claim_defendant_type text;

  v_chat_id integer;
  v_chat_length integer;
  v_chat_unread integer;
begin
  assert in_actor_id is not null;

  v_is_master := pp_utils.is_in_group(in_actor_id, 'master');
  v_is_judge := pp_utils.is_in_group(in_actor_id, 'judge');
  v_claim_code := data.get_object_code(in_object_id);

  v_claim_plaintiff_type := json.get_string_opt(data.get_attribute_value(data.get_object_id(v_claim_plaintiff), 'type'), null);

  if v_claim_defendant is not null then 
    v_claim_defendant_type := json.get_string_opt(data.get_attribute_value(data.get_object_id(v_claim_defendant), 'type'), null);
  end if;

  if v_is_master or (v_claim_author = v_actor_code and v_claim_status = 'draft') then
    v_actions_list := v_actions_list || 
        format(', "claim_edit": {"code": "claim_edit", "name": "Изменить иск", "disabled": false,'||
                '"params": {"claim_code": "%s"}, 
                 "user_params": [{"code": "title", "description": "Заголовок", "type": "string", "restrictions": {"min_length": 1}, "default_value": "%s"},
                                 {"code": "text", "description": "Текст иска", "type": "string", "restrictions": {"min_length": 1, "multiline": true}, "default_value": %s}]}',
                v_claim_code,
                json.get_string_opt(data.get_raw_attribute_value_for_share(in_object_id, 'title'), null),
                coalesce(data.get_raw_attribute_value_for_share(in_object_id, 'claim_text')::text, '""'));

    v_actions_list := v_actions_list || 
        format(', "claim_delete": {"code": "claim_delete", "name": "Удалить", "disabled": false, "warning": "Иск будет удалён безвозвратно. Удаляем?", '||
                '"params": {"claim_code": "%s"}}',
                v_claim_code);

    v_actions_list := v_actions_list || 
        format(', "claim_change_defendant": {"code": "claim_change_defendant", "name": "Изменить ответчика", "disabled": false, '||
                '"params": {"claim_code": "%s"}}',
                v_claim_code);

    if v_claim_status = 'draft' then
      v_actions_list := v_actions_list || 
          format(', "claim_send": {"code": "claim_send", "name": "Отправить на рассмотрение", "disabled": false, "warning": "После отправки вы больше не сможете изменить иск",'||
                  '"params": {"claim_code": "%s"}}',
                  v_claim_code);
    end if;
  end if;

  if v_claim_status = 'processing' and v_is_master and v_claim_to_asj then
    v_actions_list := v_actions_list || 
      format(', "claim_send_to_judge": {"code": "claim_send_to_judge", "name": "Перенаправить судье", "disabled": false,'||
             '"params": {"claim_code": "%s"}}',
             v_claim_code);
  end if;

  if v_claim_status = 'processing' and (v_is_master or (v_is_judge and not v_claim_to_asj) or (v_actor_code = 'asj' and v_claim_to_asj)) then
    v_actions_list := v_actions_list || 
      format(', "claim_result": {"code": "claim_result", "name": "Принять решение", "disabled": false,'||
             '"params": {"claim_code": "%s"}, "user_params": [{"code": "claim_result", "description": "Текст решения", "type": "string", "restrictions": {"min_length": 1, "multiline": true}}]}',
             v_claim_code);
  end if;

  if v_claim_status = 'done' and v_is_master then
    v_actions_list := v_actions_list || 
      format(', "claim_result_edit": {"code": "claim_result_edit", "name": "Редактировать решение", "disabled": false,'||
             '"params": {"claim_code": "%s"}, 
             "user_params": [{"code": "claim_result", "description": "Текст решения", "type": "string", "restrictions": {"min_length": 1, "multiline": true}, "default_value": %s}]}',
             v_claim_code,
             coalesce(data.get_raw_attribute_value_for_share(in_object_id, 'claim_result_text')::text, '""'));
  end if;

  v_chat_id := data.get_object_id(v_claim_code || '_chat');
  if v_chat_id is not null 
  and (v_is_master 
    or v_is_judge
    or v_claim_author = v_actor_code 
    or v_actor_code = 'asj' -- автоматическая система судопроизводства
    or (v_claim_defendant_type = 'person' and v_actor_code = v_claim_defendant)
    or (v_claim_plaintiff_type = 'organization' and pp_utils.is_in_group(in_actor_id, v_claim_plaintiff || '_head'))
    or (v_claim_defendant_type = 'organization' and pp_utils.is_in_group(in_actor_id, v_claim_defendant || '_head'))) then
    v_chat_length := json.get_integer_opt(data.get_attribute_value(v_chat_id, 'system_chat_length'), 0);
    v_chat_unread := json.get_integer_opt(data.get_attribute_value(v_chat_id, 'chat_unread_messages', in_actor_id), null);
    v_actions_list := v_actions_list || 
        format(', "claim_chat": {"code": "chat_enter", "name": "Обсудить%s", "disabled": false, '||
                '"params": {"object_code": "%s"}}',
                case when v_chat_length = 0 then ''
                when v_chat_length > 0 and v_chat_unread is null then ' (' || v_chat_length || ')'
                else ' (' || v_chat_length || ', непрочитанных ' || v_chat_unread || ')' 
                end,
                v_claim_code);
  end if;

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
