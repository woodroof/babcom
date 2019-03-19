-- drop function pallas_project.actgenerator_blog(integer, integer);

create or replace function pallas_project.actgenerator_blog(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_is_master boolean;
  v_blog_code text;
  v_blog_is_mute boolean;
  v_blog_author integer := json.get_integer(data.get_attribute_value(in_object_id, 'system_blog_author'));
begin
  assert in_actor_id is not null;

  v_is_master := pp_utils.is_in_group(in_actor_id, 'master');
  v_blog_code := data.get_object_code(in_object_id);

  if v_blog_author <> in_actor_id then
    v_blog_is_mute := json.get_boolean_opt(data.get_raw_attribute_value_for_share(in_object_id, 'blog_is_mute', in_actor_id), false);
    v_actions_list := v_actions_list || 
          format(', "blog_mute": {"code": "blog_mute", "name": "%s", "disabled": false,'||
                  '"params": {"blog_code": "%s", "mute_on_off": "%s"}}',
                  case when v_blog_is_mute then
                    'Включить уведомления'
                  else 'Отключить уведомления' end,
                  v_blog_code,
                  case when v_blog_is_mute then
                    'off'
                  else 'on' end);
  end if;

  if v_is_master or v_blog_author = in_actor_id then
    v_actions_list := v_actions_list || 
        format(', "blog_rename": {"code": "blog_rename", "name": "Переименовать блог", "disabled": false,'||
                '"params": {"blog_code": "%s"}, 
                 "user_params": [{"code": "title", "description": "Введите имя блога", "type": "string", "restrictions": {"min_length": 1}, "default_value": %s},
                                 {"code": "subtitle", "description": "Введите описание блога", "type": "string", "default_value": %s}]}',
                v_blog_code,
                coalesce(data.get_raw_attribute_value_for_share(in_object_id, 'title')::text, '""'),
                coalesce(data.get_raw_attribute_value_for_share(in_object_id, 'subtitle')::text, '""'));

    v_actions_list := v_actions_list || 
        format(', "blog_write": {"code": "blog_write", "name": "Написать", "disabled": false, '||
                '"params": {"blog_code": "%s"}, 
                 "user_params": [{"code": "title", "description": "Введите заголовок сообщения", "type": "string", "restrictions": {"min_length": 1}},
                                 {"code": "message_text", "description": "Введите текст сообщения", "type": "string", "restrictions": {"multiline": true}}]}',
                v_blog_code);
  end if;

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
