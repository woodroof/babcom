-- drop function pallas_project.actgenerator_chat(integer, integer);

create or replace function pallas_project.actgenerator_chat(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_is_master boolean;
  v_chat_code text;
  v_chat_is_mute boolean;
  v_chat_can_invite boolean;
  v_chat_can_leave boolean;
  v_chat_can_mute boolean;
  v_chat_can_rename boolean;
  v_chat_cant_write boolean;
  v_chat_cant_see_members boolean;
  v_chat_parent_list text;
begin
  assert in_actor_id is not null;

  v_is_master := pp_utils.is_in_group(in_actor_id, 'master');
  v_chat_code := data.get_object_code(in_object_id);

  v_chat_parent_list := json.get_string_opt(data.get_attribute_value(in_object_id, 'system_chat_parent_list'), '~');
  v_chat_can_invite := json.get_boolean_opt(data.get_attribute_value_for_share(in_object_id, 'system_chat_can_invite'), false);
  v_chat_can_leave := json.get_boolean_opt(data.get_attribute_value_for_share(in_object_id, 'system_chat_can_leave'), false);
  v_chat_can_mute := json.get_boolean_opt(data.get_attribute_value_for_share(in_object_id, 'system_chat_can_mute'), false);
  v_chat_can_rename := json.get_boolean_opt(data.get_attribute_value_for_share(in_object_id, 'system_chat_can_rename'), false);
  v_chat_cant_write := json.get_boolean_opt(data.get_attribute_value_for_share(in_object_id, 'system_chat_cant_write'), false);
  v_chat_cant_see_members := json.get_boolean_opt(data.get_attribute_value_for_share(in_object_id, 'system_chat_cant_see_members'), false);

  if not v_chat_cant_see_members then
    v_actions_list := v_actions_list || 
        format(', "chat_add_person": {"code": "chat_add_person", "name": "%s участников", "disabled": false, '||
                '"params": {"chat_code": "%s"}}',
                case when v_is_master and v_chat_parent_list <> 'master_chats' or v_chat_can_invite then 'Добавить/посмотреть'
                else 'Посмотреть' end,
                v_chat_code);
  end if;

  if pp_utils.is_in_group(in_actor_id, v_chat_code) and (v_is_master and v_chat_parent_list <> 'master_chats' or v_chat_can_leave) then
    v_actions_list := v_actions_list || 
        format(', "chat_leave": {"code": "chat_leave", "name": "Выйти из чата", "disabled": false, "warning": "Вы уверены? Этот чат исчезнет из вашего списка чатов, и вернуться вы не сможете.",'||
                '"params": {"chat_code": "%s"}}',
                v_chat_code);
  end if;

  if pp_utils.is_in_group(in_actor_id, v_chat_code) and (v_is_master and v_chat_parent_list <> 'master_chats' or v_chat_can_mute) then
    v_chat_is_mute := json.get_boolean_opt(data.get_raw_attribute_value_for_share(in_object_id, 'chat_is_mute', in_actor_id), false);
    v_actions_list := v_actions_list || 
        format(', "chat_mute": {"code": "chat_mute", "name": "%s", "disabled": false,'||
                '"params": {"chat_code": "%s", "mute_on_off": "%s"}}',
                case when v_chat_is_mute then
                  'Включить уведомления'
                else 'Отключить уведомления' end,
                v_chat_code,
                case when v_chat_is_mute then
                  'off'
                else 'on' end);
  end if;

  if (v_is_master and v_chat_parent_list <> 'master_chats') or v_chat_can_rename then
    v_actions_list := v_actions_list || 
        format(', "chat_rename": {"code": "chat_rename", "name": "Переименовать чат", "disabled": false, "warning": "Чат поменяет имя для всех его участников.",'||
                '"params": {"chat_code": "%s"}, "user_params": [{"code": "title", "description": "Введите имя чата", "type": "string", "restrictions": {"min_length": 1}, "default_value": "%s"}]}',
                v_chat_code,
                json.get_string_opt(data.get_raw_attribute_value_for_share(in_object_id, 'title'), null));
  end if;

  if not v_chat_cant_write and (not v_is_master or v_chat_parent_list = 'master_chats') then
    v_actions_list := v_actions_list || 
        format(', "chat_write": {"code": "chat_write", "name": "Написать", "disabled": false, '||
                '"params": {"chat_code": "%s"}, "user_params": [{"code": "message_text", "description": "Введите текст сообщения", "type": "string", "restrictions": {"multiline": true}}]}',
                v_chat_code);
  end if;

  if v_is_master and not pp_utils.is_in_group(in_actor_id, v_chat_code) then
    v_actions_list := v_actions_list || 
          format(', "chat_enter": {"code": "chat_enter", "name": "Следить", "disabled": false, '||
                  '"params": {"chat_code": "%s"}}',
                  v_chat_code);
  end if;

  if v_is_master then
    v_actions_list := v_actions_list || 
        format(', "chat_change_can_invite": {"code": "chat_change_settings", "name": "%s приглашать участников", "disabled": false, '||
                '"params": {"chat_code": "%s", "parameter": "can_invite", "value": "%s"}}',
                case when v_chat_can_invite then 'Запретить' else 'Разрешить' end,
                v_chat_code,
                case when v_chat_can_invite then 'off' else 'on' end);

    v_actions_list := v_actions_list || 
        format(', "chat_change_can_leave": {"code": "chat_change_settings", "name": "%s выходить из чата", "disabled": false, '||
                '"params": {"chat_code": "%s", "parameter": "can_leave", "value": "%s"}}',
                case when v_chat_can_leave then 'Запретить' else 'Разрешить' end,
                v_chat_code,
                case when v_chat_can_leave then 'off' else 'on' end);

    v_actions_list := v_actions_list || 
        format(', "chat_change_can_mute": {"code": "chat_change_settings", "name": "%s отключать уведомления", "disabled": false, %s'||
                '"params": {"chat_code": "%s", "parameter": "can_mute", "value": "%s"}}',
                case when v_chat_can_mute then 'Запретить' else 'Разрешить' end,
                case when v_chat_can_mute then '"warning": "Это действие включит уведомления для всех участников чата",' else '' end,
                v_chat_code,
                case when v_chat_can_mute then 'off' else 'on' end);

    v_actions_list := v_actions_list || 
        format(', "chat_change_can_rename": {"code": "chat_change_settings", "name": "%s переименование чата", "disabled": false, '||
                '"params": {"chat_code": "%s", "parameter": "can_rename", "value": "%s"}}',
                case when v_chat_can_rename then 'Запретить' else 'Разрешить' end,
                v_chat_code,
                case when v_chat_can_rename then 'off' else 'on' end);
  end if;

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
