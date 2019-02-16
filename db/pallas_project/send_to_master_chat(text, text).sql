-- drop function pallas_project.send_to_master_chat(text, text);

create or replace function pallas_project.send_to_master_chat(in_text text, in_object_code text default null::text)
returns void
volatile
as
$$
declare
  v_message_id integer;
  v_message_code text;
  v_message_class_id integer := data.get_class_id('message');

  v_text text;

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_message_text_attribute_id integer := data.get_attribute_id('message_text');
  v_system_message_sender_attribute_id integer := data.get_attribute_id('system_message_sender');
  v_system_message_time_attribute_id integer := data.get_attribute_id('system_message_time');

  v_master_chats_id integer := data.get_object_id('master_chats');
  v_master_chat_id integer := data.get_object_id('master_chat');

  v_master_group_id integer := data.get_object_id('master');

  v_chat_bot_id integer := data.get_object_id('chat_bot');
  v_chat_bot_title text := json.get_string(data.get_attribute_value(v_chat_bot_id, v_title_attribute_id, v_master_group_id));

  v_title text := pp_utils.format_date(clock_timestamp()) || E'\n' || v_chat_bot_title;
  v_chat_title text := json.get_string_opt(data.get_attribute_value(v_master_chat_id, v_title_attribute_id, v_master_group_id), null);

  v_person_id integer;

  v_chat_unread_messages integer;
  v_chat_unread_messages_attribute_id integer := data.get_attribute_id('chat_unread_messages');
begin
  if in_object_code is not null then
    v_text := in_text || '. [Перейти](babcom:'||in_object_code||')';
  else
   v_text := in_text;
  end if;
  -- Создаём новое сообщение
  insert into data.objects(class_id) values (v_message_class_id) returning id, code into v_message_id, v_message_code;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_message_id, v_title_attribute_id, to_jsonb(v_title), null),
  (v_message_id, v_message_text_attribute_id, to_jsonb(v_text), null),
  (v_message_id, v_system_message_sender_attribute_id, to_jsonb(v_chat_bot_id), null),
  (v_message_id, v_system_message_time_attribute_id, to_jsonb(to_char(clock_timestamp(),'DD.MM.YYYY hh24:mi:ss') ), null);

  -- Добавляем сообщение в чат
  perform pp_utils.list_prepend_and_notify(v_master_chat_id, v_message_code, null, v_master_group_id);

  -- Перекладываем этот чат в начало в мастерском списке чатов
  perform pp_utils.list_replace_to_head_and_notify(v_master_chats_id, 'master_chat', v_master_group_id);

  -- Отправляем нотификацию о новом сообщении всем неподписанным на этот чат
  for v_person_id in 
    (select oo.object_id from data.object_objects oo 
     where oo.parent_object_id = v_master_chat_id
       and oo.parent_object_id <> oo.object_id)
  loop
    if not pp_utils.is_actor_subscribed(v_person_id, v_master_chat_id) then
      v_chat_unread_messages := json.get_integer_opt(data.get_attribute_value(v_master_chat_id, v_chat_unread_messages_attribute_id, v_person_id), 0);
      perform data.change_object_and_notify(v_master_chat_id, 
                                            jsonb_build_array(data.attribute_change2jsonb(v_chat_unread_messages_attribute_id, to_jsonb(v_chat_unread_messages + 1), v_person_id)),
                                            v_person_id);
    end if;
    perform pp_utils.add_notification_if_not_subscribed(v_person_id, 'Мастерский чат: ' || in_text, v_master_chat_id);
  end loop;
end;
$$
language plpgsql;
