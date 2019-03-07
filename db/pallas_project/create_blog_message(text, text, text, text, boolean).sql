-- drop function pallas_project.create_blog_message(text, text, text, text, boolean);

create or replace function pallas_project.create_blog_message(in_blog_code text, in_title text, in_message text, in_time text default null::text, in_without_notification boolean default true)
returns void
volatile
as
$$
declare
  v_blog_id integer := data.get_object_id(in_blog_code);

  v_person_id integer;

  v_message_id integer;
  v_message_code text;

  v_news_id integer := data.get_object_id('news');
  v_master_id integer := data.get_object_id('master');
  v_all_person_id integer := data.get_object_id('all_person');
  v_notification_text text;

  v_is_actor_subscribed boolean;
  v_time text := coalesce(in_time, pp_utils.format_date(clock_timestamp()));
begin
  -- создаём новое сообщение
  v_message_id := data.create_object(
    null,
    jsonb_build_array(
      jsonb_build_object('code', 'title', 'value', in_title),
      jsonb_build_object('code', 'blog_name', 'value', in_blog_code),
      jsonb_build_object('code', 'blog_message_text', 'value', in_message),
      jsonb_build_object('code', 'blog_message_time', 'value', v_time)
    ),
    'blog_message');
  v_message_code := data.get_object_code(v_message_id);

  perform pallas_project.create_chat(v_message_code || '_chat',
                   jsonb_build_object(
                   'content', jsonb '[]',
                   'title', 'Обсуждение новости ' || in_title,
                   'system_chat_is_renamed', true,
                   'system_chat_can_invite', false,
                   'system_chat_can_leave', false,
                   'system_chat_can_rename', false,
                   'system_chat_cant_see_members', true,
                   'system_chat_length', 0
                 ));

  -- Добавляем сообщение в блог
    perform pp_utils.list_prepend_and_notify(v_blog_id, v_message_code, null);
  -- Кладём сообщение в начало ленты новостей
    perform pp_utils.list_prepend_and_notify(v_news_id, v_message_code, null);

  if not in_without_notification then
     v_notification_text := 'Новое сообщение ' || in_title || ' в блоге '|| pp_utils.link(in_blog_code);
    -- Отправляем нотификацию о новом сообщении всем неподписанным на этот блог
    for v_person_id in 
        (select distinct oo.object_id from data.object_objects oo 
          where oo.parent_object_id in (v_master_id, v_all_person_id)
            and oo.parent_object_id <> oo.object_id)
    loop
        v_is_actor_subscribed := pp_utils.is_actor_subscribed(v_person_id, v_blog_id) or pp_utils.is_actor_subscribed(v_person_id, v_news_id);
        if not v_is_actor_subscribed
          and not json.get_boolean_opt(data.get_raw_attribute_value_for_share(v_blog_id, 'blog_is_mute', v_person_id), false) then
          perform pp_utils.add_notification(v_person_id, v_notification_text, v_message_id);
        end if;
    end loop;
  end if;

end;
$$
language plpgsql;
