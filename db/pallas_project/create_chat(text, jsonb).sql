-- drop function pallas_project.create_chat(text, jsonb);

create or replace function pallas_project.create_chat(in_code text, in_attributes jsonb)
returns integer
volatile
as
$$
declare
  v_chat_id  integer;
  v_chat_code text;

  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_chat_is_master boolean := (json.get_string_opt(in_attributes,'system_chat_parent_list', '~') = 'master_chats');
  v_chat_can_invite boolean:= json.get_boolean_opt(in_attributes,'system_chat_can_invite', true);
  v_chat_title text := json.get_string_opt(in_attributes, 'title', '');

  v_content text[];
  v_list_attributes jsonb;
begin
  -- создаём новый чат
  v_chat_id := data.create_object(in_code, in_attributes, 'chat');
  v_chat_code := data.get_object_code(v_chat_id);

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_chat_id, v_is_visible_attribute_id, jsonb 'true', v_chat_id);

  v_list_attributes := jsonb_build_array(
    jsonb_build_object('code', 'title', 'value', 'Участники чата ' || v_chat_title),
    jsonb_build_object('code', 'is_visible', 'value', true, 'value_object_id', v_chat_id),
    jsonb_build_object('code', 'chat_person_list_persons', 'value', '')
  );

  -- Собираем список всех персонажей, кроме тех, кто уже в чате
  if v_chat_can_invite then
    v_content := pallas_project.get_chat_possible_persons(v_chat_id, v_chat_is_master);

    v_list_attributes := v_list_attributes || jsonb_build_array(
      jsonb_build_object('code', 'content', 'value', v_content, 'value_object_code', 'master'),
      jsonb_build_object('code', 'content', 'value', v_content, 'value_object_id', v_chat_id),
      jsonb_build_object('code', 'chat_person_list_content_label', 'value', '-------------------------------
Кого добавляем?', 'value_object_code', 'master'),
      jsonb_build_object('code', 'chat_person_list_content_label', 'value', '-------------------------------
Кого добавляем?', 'value_object_id', v_chat_id)
    );
  elsif not v_chat_is_master then
    v_list_attributes := v_list_attributes || jsonb_build_array(
      jsonb_build_object('code', 'content', 'value', v_content, 'value_object_code', 'master'),
      jsonb_build_object('code', 'chat_person_list_content_label', 'value', '-------------------------------
Кого добавляем?', 'value_object_code', 'master')
    );
  end if;

  perform data.create_object( v_chat_code || '_person_list', v_list_attributes, 'chat_person_list');

  return v_chat_id;
end;
$$
language plpgsql;
