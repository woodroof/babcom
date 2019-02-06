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
begin
  assert in_actor_id is not null;

  v_is_master := pp_utils.is_in_group(in_actor_id, 'master');
  v_chat_code := data.get_object_code(in_object_id);

  if v_is_master or json.get_boolean_opt(data.get_attribute_value(in_object_id, 'system_chat_can_invite', in_actor_id), false) then
    v_actions_list := v_actions_list || 
        format(', "chat_add_person": {"code": "chat_add_person", "name": "Добавить/посмотреть участников", "disabled": false, '||
                '"params": {"chat_code": "%s"}}',
                v_chat_code);
  end if;

  if pp_utils.is_in_group(in_actor_id, v_chat_code) and (v_is_master or json.get_boolean_opt(data.get_attribute_value(in_object_id, 'system_chat_can_leave', in_actor_id), false)) then
    v_actions_list := v_actions_list || 
        format(', "chat_leave": {"code": "chat_leave", "name": "Выйти из чата", "disabled": false, "warning": "Вы уверены? Этот чат исчезнет из вашего списка чатов, и вернуться вы не сможете.",'||
                '"params": {"chat_code": "%s"}}',
                v_chat_code);
  end if;

  if pp_utils.is_in_group(in_actor_id, v_chat_code) and (v_is_master or json.get_boolean_opt(data.get_attribute_value(in_object_id, 'system_chat_can_mute', in_actor_id), false)) then
    v_chat_is_mute := json.get_boolean_opt(data.get_attribute_value(in_object_id, 'chat_is_mute', in_actor_id), false);
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

  if pp_utils.is_in_group(in_actor_id, v_chat_code) and (v_is_master or json.get_boolean_opt(data.get_attribute_value(in_object_id, 'system_chat_can_rename', in_actor_id), false)) then
    v_actions_list := v_actions_list || 
        format(', "chat_rename": {"code": "chat_rename", "name": "Переименовать чат", "disabled": false, "warning": "Чат поменяет имя для всех его участников.",'||
                '"params": {"chat_code": "%s"}, "user_params": [{"code": "title", "description": "Введите имя чата", "type": "string", "restrictions": {"min_length": 1}, "default_value": "%s"}]}',
                v_chat_code,
                json.get_string_opt(data.get_attribute_value(in_object_id, 'title', in_actor_id), null));
  end if;

  v_actions_list := v_actions_list || 
        format(', "chat_write": {"code": "chat_write", "name": "Написать", "disabled": false, '||
                '"params": {"chat_code": "%s"}, "user_params": [{"code": "message_text", "description": "Введите текст сообщения", "type": "string", "restrictions": {"multiline": true}}]}',
                v_chat_code);

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
