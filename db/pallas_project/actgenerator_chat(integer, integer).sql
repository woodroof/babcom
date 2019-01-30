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

  v_is_master := pallas_project.is_in_group(in_actor_id, 'master');
  v_chat_code := data.get_object_code(in_object_id);

  if v_is_master or json.get_boolean_opt(data.get_attribute_value(in_object_id, 'system_chat_can_invite', in_actor_id), false) then
    v_actions_list := v_actions_list || 
        format(', "chat_add_person": {"code": "chat_add_person", "name": "Добавить участника", "disabled": false, '||
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
