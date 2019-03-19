-- drop function pallas_project.actgenerator_blog_content(integer, integer, integer);

create or replace function pallas_project.actgenerator_blog_content(in_object_id integer, in_list_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_is_master boolean;
  v_blog_message_code text;
  v_blog_name text := json.get_string(data.get_raw_attribute_value_for_share(in_list_object_id, 'blog_name'));
  v_blog_author integer := json.get_integer(data.get_attribute_value(data.get_object_id(v_blog_name), 'system_blog_author'));
  v_chat_id integer;
  v_chat_length integer;
  v_chat_unread integer;
  v_is_like boolean;
  v_like_count integer;
begin
  assert in_actor_id is not null;

  v_is_master := pp_utils.is_in_group(in_actor_id, 'master');
  v_blog_message_code := data.get_object_code(in_list_object_id);

  if v_is_master or v_blog_author = in_actor_id then
    v_actions_list := v_actions_list || 
        format(', "blog_message_edit": {"code": "blog_message_edit", "name": "Редактировать", "disabled": false,'||
                '"params": {"blog_message_code": "%s", "is_list": true}, 
                 "user_params": [{"code": "title", "description": "Заголовок", "type": "string", "restrictions": {"min_length": 1}, "default_value": %s},
                                 {"code": "text", "description": "Текст сообщения", "type": "string", "restrictions": {"min_length": 1, "multiline": true}, "default_value": %s}]}',
                v_blog_message_code,
                coalesce(data.get_raw_attribute_value_for_share(in_list_object_id, 'title')::text, '""'),
                coalesce(data.get_raw_attribute_value_for_share(in_list_object_id, 'blog_message_text')::text, '""'));

    v_actions_list := v_actions_list || 
        format(', "blog_message_delete": {"code": "blog_message_delete", "name": "Удалить", "disabled": false, "warning": "Сообщение будет удалено вместе со всеми комментариями. Удаляем?", '||
                '"params": {"blog_message_code": "%s", "is_list": true}}',
                v_blog_message_code);
  end if;

  v_chat_id := data.get_object_id(v_blog_message_code || '_chat');
  if v_chat_id is not null then
    v_chat_length := json.get_integer_opt(data.get_attribute_value(v_chat_id, 'system_chat_length'), 0);
    v_chat_unread := json.get_integer_opt(data.get_attribute_value(v_chat_id, 'chat_unread_messages', in_actor_id), null);
    v_actions_list := v_actions_list || 
        format(', "blog_message_chat": {"code": "chat_enter", "name": "Обсудить%s", "disabled": false, '||
                '"params": {"object_code": "%s"}}',
                case when v_chat_length = 0 then ''
                when v_chat_length > 0 and v_chat_unread is null then ' (' || v_chat_length || ')'
                else ' (' || v_chat_length || ', непрочитанных ' || v_chat_unread || ')' 
                end,
                v_blog_message_code);
  end if;

  v_is_like := json.get_boolean_opt(data.get_raw_attribute_value_for_share(in_list_object_id, 'system_blog_message_like', in_actor_id), false);
  v_like_count := json.get_integer_opt(data.get_raw_attribute_value_for_share(in_list_object_id, 'blog_message_like_count'), 0);
  v_actions_list := v_actions_list || 
        format(', "blog_message_like": {"code": "blog_message_like", "name": "%s", "disabled": false,'||
                '"params": {"blog_message_code": "%s", "like_on_off": "%s", "is_list": true}}',
                case when v_is_like then
                  '🧡 ' || v_like_count
                else '💙 ' || v_like_count end,
                v_blog_message_code,
                case when v_is_like then
                  'off'
                else 'on' end);

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
