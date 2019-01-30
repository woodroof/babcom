-- drop function pallas_project.act_create_chat(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_create_chat(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_chat_code text;
  v_chat_id  integer;
  v_chat_class_id integer := data.get_class_id('chat');
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');

  v_all_chats_id integer := data.get_object_id('all_chats');
  v_chats_id integer := data.get_object_id('chats');
  v_master_group_id integer := data.get_object_id('master');

  v_content text[];
  v_new_content text[];

begin
  assert in_request_id is not null;
  -- создаём новый чат
  insert into data.objects(class_id) values (v_chat_class_id) returning id, code into v_chat_id, v_chat_code;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_chat_id, v_title_attribute_id, to_jsonb('Чат: '|| json.get_string(data.get_attribute_value(v_actor_id, v_title_attribute_id, v_actor_id))), null),
  (v_chat_id, v_is_visible_attribute_id, jsonb 'true', v_chat_id),
  (v_chat_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id);

  -- Добавляем заведшего чат в группу имени этого чата
  perform data.process_diffs_and_notify(data.change_object_groups(v_actor_id, array[v_chat_id], array[]::integer[], v_actor_id));

  -- Добавляем его в список всех и в список моих для того, кто создаёт
  -- Блокируем списки
  perform * from data.objects where id = v_all_chats_id for update;
  perform * from data.objects where id = v_chats_id for update;

  -- Достаём, меняем, кладём назад
  v_content := array[]::text[];
  v_content := json.get_string_array_opt(data.get_attribute_value(v_all_chats_id, 'content', v_master_group_id), v_content);
  v_new_content := array_prepend(v_chat_code, v_content);
  if v_new_content <> v_content then
    perform data.change_object_and_notify(v_all_chats_id, 
                                          jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_master_group_id, to_jsonb(v_new_content))),
                                          v_actor_id);
  end if;
  v_content := array[]::text[];
  v_content := json.get_string_array_opt(data.get_attribute_value(v_chats_id,'content', v_actor_id), v_content);
  v_new_content := array_prepend(v_chat_code, v_content);
  if v_new_content <> v_content then
    perform data.change_object_and_notify(v_chats_id, 
                                         jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_actor_id, to_jsonb(v_new_content))),
                                         v_actor_id);
  end if;

  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'action',
    format('{"action": "open_object", "action_data": {"object_id": "%s"}}', v_chat_code)::jsonb);
end;
$$
language plpgsql;
