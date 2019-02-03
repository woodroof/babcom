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

  if pp_utils.is_in_group(in_actor_id, v_chat_code) and json.get_boolean_opt(data.get_attribute_value(in_object_id, 'system_chat_can_leave', in_actor_id), false) then
    v_actions_list := v_actions_list || 
        format(', "chat_leave": {"code": "chat_leave", "name": "Выйти из чата", "disabled": false, "warning": "Вы уверены? Этот чат исчезнет из вашего списка чатов, и вернуться вы не сможете.",'||
                '"params": {"chat_code": "%s"}}',
                v_chat_code);
  end if;

  v_actions_list := v_actions_list || 
        format(', "chat_write": {"code": "chat_write", "name": "Написать", "disabled": false, '||
                '"params": {"chat_code": "%s"}, "user_params": [{"code": "message_text", "description": "Введите текст сообщения", "type": "string", "restrictions": {"multiline": true}}]}',
                v_chat_code);

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
