-- drop function pallas_project.act_blog_write(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_blog_write(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_blog_code text := json.get_string(in_params, 'blog_code');
  v_blog_id integer := data.get_object_id(v_blog_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_person_id integer;

  v_message_title text := json.get_string(in_user_params, 'title');
  v_message_text text := json.get_string(in_user_params, 'message_text');
  v_message_id integer;
  v_message_code text;

  v_content_attribute_id integer := data.get_attribute_id('content');

  v_news_id integer := data.get_object_id('news');
  v_master_id integer := data.get_object_id('master');
  v_all_person_id integer := data.get_object_id('all_person');
  v_notification_text text;

  v_content text[];
  v_new_content text[];
  v_message_sent boolean := false;

  v_is_actor_subscribed boolean;
  v_changes jsonb[];
begin
  assert in_request_id is not null;

  -- создаём новое сообщение
  v_message_id := data.create_object(
    null,
    jsonb_build_array(
      jsonb_build_object('code', 'title', 'value', v_message_title),
      jsonb_build_object('code', 'blog_name', 'value', to_jsonb(v_blog_code)),
      jsonb_build_object('code', 'blog_message_text', 'value', to_jsonb(v_message_text)),
      jsonb_build_object('code', 'blog_message_time', 'value', to_jsonb(pp_utils.format_date(clock_timestamp())))
    ),
    'blog_message');
  v_message_code := data.get_object_code(v_message_id);

  perform pallas_project.create_chat(v_message_code || '_chat',
                   jsonb_build_object(
                   'content', jsonb '[]',
                   'title', 'Обсуждение новости ' || v_message_title,
                   'system_chat_is_renamed', true,
                   'system_chat_can_invite', false,
                   'system_chat_can_leave', false,
                   'system_chat_can_rename', false,
                   'system_chat_cant_see_members', true,
                   'system_chat_length', 0
                 ));

  -- Добавляем сообщение в блог
  v_changes := array[]::jsonb[];
  v_content := json.get_string_array_opt(data.get_raw_attribute_value_for_update(v_blog_id, v_content_attribute_id), array[]::text[]);
  v_new_content := array_prepend(v_message_code, v_content);
  if v_new_content <> v_content then
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_content_attribute_id, to_jsonb(v_new_content)));
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_blog_id, 
                                                 to_jsonb(v_changes));

  -- Кладём сообщение в начало ленты новостей
    perform pp_utils.list_prepend_and_notify(v_news_id, v_message_code, null);

  v_notification_text := 'Новое сообщение ' || v_message_title || ' в блоге '|| pp_utils.link(v_blog_code);
  -- Отправляем нотификацию о новом сообщении всем неподписанным на этот чат
  for v_person_id in 
      (select distinct oo.object_id from data.object_objects oo 
        where oo.parent_object_id in (v_master_id, v_all_person_id)
          and oo.parent_object_id <> oo.object_id)
    loop
      v_is_actor_subscribed := pp_utils.is_actor_subscribed(v_person_id, v_blog_id) or pp_utils.is_actor_subscribed(v_person_id, v_news_id);
      if v_person_id <> v_actor_id 
        and not v_is_actor_subscribed
        and not json.get_boolean_opt(data.get_raw_attribute_value_for_share(v_blog_id, 'blog_is_mute', v_person_id), false) then
        perform pp_utils.add_notification(v_person_id, v_notification_text, v_message_id);
      end if;
    end loop;
  end if;

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
