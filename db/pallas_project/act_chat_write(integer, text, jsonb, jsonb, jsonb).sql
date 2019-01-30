-- drop function pallas_project.act_chat_write(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_chat_write(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_chat_code text := json.get_string(in_params, 'chat_code');
  v_chat_id integer := data.get_object_id(v_chat_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_person_id integer;

  v_message_text text := json.get_string(in_user_params, 'message_text');

  v_message_id integer;
  v_message_code text;
  v_message_class_id integer := data.get_class_id('message');

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_message_text_attribute_id integer := data.get_attribute_id('message_text');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_system_message_sender_attribute_id integer := data.get_attribute_id('system_message_sender');
  v_system_message_time_attribute_id integer := data.get_attribute_id('system_message_time');

  v_master_group_id integer := data.get_object_id('master');

  v_content text[];
  v_new_content text[];
  v_message_sent boolean := false;

  v_actor_title text := json.get_string(data.get_attribute_value(v_actor_id, v_title_attribute_id, v_actor_id));
  v_title text := to_char(clock_timestamp(),'DD.MM hh24:mi:ss ') || v_actor_title;
begin
  assert in_request_id is not null;
  -- создаём новое сообщение
  insert into data.objects(class_id) values (v_message_class_id) returning id, code into v_message_id, v_message_code;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_message_id, v_title_attribute_id, to_jsonb(v_title), null),
  (v_message_id, v_message_text_attribute_id, to_jsonb(v_message_text), null),
  (v_message_id, v_is_visible_attribute_id, jsonb 'true', v_chat_id),
  (v_message_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (v_message_id, v_system_message_sender_attribute_id, to_jsonb(v_actor_id), null),
  (v_message_id, v_system_message_time_attribute_id, to_jsonb(to_char(clock_timestamp(),'DD.MM.YYYY hh24:mi:ss') ), null);

  -- Добавляем сообщение в чат
  perform * from data.objects where id = v_chat_id for update;

  -- Достаём, меняем, кладём назад
  v_content := json.get_string_array_opt(data.get_attribute_value(v_chat_id, 'content', v_actor_id), array[]::text[]);
  v_new_content := array_prepend(v_message_code, v_content);
  if v_new_content <> v_content then
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_chat_id, 
                                                 jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_actor_id, to_jsonb(v_new_content))));
  end if;

  -- Отправляем нотификацию о новом сообщении всем неподписанным на этот чат
  for v_person_id in 
    (select oo.object_id from data.object_objects oo 
      where oo.parent_object_id = v_chat_id
        and oo.parent_object_id <> oo.object_id
        and oo.object_id <> v_actor_id)
  loop
    if not json.get_boolean_opt(data.get_attribute_value(v_chat_id, 'system_chat_is_mute', v_person_id), false) then
      perform pallas_project.add_notification_if_not_subscribed(v_person_id, 'Новое сообщение от '|| v_actor_title, v_chat_id);
    end if;
  end loop;

  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language plpgsql;
