-- drop function pallas_project.send_to_important_notifications(integer, text, text);

create or replace function pallas_project.send_to_important_notifications(in_actor_id integer, in_text text, in_object_code text default null::text)
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

  v_important_notifications_id integer := data.get_object_id('important_notifications');
  v_chat_id integer := data.get_integer_opt(get_attribute_value(v_important_notifications_id, 'redirect', in_actor_id), null);

  v_chat_bot_id integer := data.get_object_id('chat_bot');
  v_chat_bot_title text := json.get_string(data.get_attribute_value(v_chat_bot_id, v_title_attribute_id, in_actor_id));

  v_title text := pp_utils.format_date(clock_timestamp());

  v_content text[];
  v_new_content text[];
  v_changes jsonb[];

  v_system_chat_length_attribute_id integer := data.get_attribute_id('system_chat_length');
  v_chat_length integer;
  v_chat_unread_messages integer;
  v_chat_unread_messages_attribute_id integer := data.get_attribute_id('chat_unread_messages');
begin
  assert v_chat_id is not null;

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
  perform pp_utils.list_prepend_and_notify(v_chat_id, v_message_code, null, in_actor_id);

end;
$$
language plpgsql;
