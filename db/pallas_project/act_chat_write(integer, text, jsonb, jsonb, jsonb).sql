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

  v_message_text text := json.get_string(in_user_params, 'message_text');

  v_message_id integer;
  v_message_code text;
  v_message_class_id integer := data.get_class_id('message');

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_subtitle_attribute_id integer := data.get_attribute_id('subtitle');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_system_message_sender_attribute_id integer := data.get_attribute_id('system_message_sender');
  v_system_message_time_attribute_id integer := data.get_attribute_id('system_message_time');

  v_master_group_id integer := data.get_object_id('master');

  v_content text[];
  v_new_content text[];
  v_message_sent boolean := false;

  v_title text := to_char(clock_timestamp(),'DD.MM hh24:mi:ss') || json.get_string(data.get_attribute_value(v_actor_id, v_title_attribute_id, v_actor_id));
begin
  assert in_request_id is not null;
  -- создаём новое сообщение
  insert into data.objects(class_id) values (v_message_class_id) returning id, code into v_message_id, v_message_code;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_message_id, v_title_attribute_id, to_jsonb(v_title), null),
  (v_message_id, v_subtitle_attribute_id, to_jsonb(v_message_text), null),
  (v_message_id, v_is_visible_attribute_id, jsonb 'true', v_chat_id),
  (v_message_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (v_message_id, v_system_message_sender_attribute_id, to_jsonb(v_actor_id), null),
  (v_message_id, v_system_message_time_attribute_id, to_jsonb(to_char(clock_timestamp(),'DD.MM.YYYY hh24:mi:ss') ), null);

  -- Добавляем сообщение в чат
  perform * from data.objects where id = v_chat_id for update;

  -- Достаём, меняем, кладём назад
  v_content := array[]::text[];
  v_content := json.get_string_array_opt(data.get_attribute_value(v_chat_id, 'content', v_actor_id), v_content);
  v_new_content := array_prepend(v_message_code, v_content);
  if v_new_content <> v_content then
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_chat_id, 
                                                 jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_actor_id, to_jsonb(v_new_content))));
  end if;

  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language plpgsql;
