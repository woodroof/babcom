-- drop function pallas_project.create_chat(text);

create or replace function pallas_project.create_chat(in_chat_subtitle text)
returns integer
volatile
as
$$
declare
  v_chat_id  integer;
  v_chat_class_id integer := data.get_class_id('chat');

  v_subtitle_attribute_id integer := data.get_attribute_id('subtitle');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_content_attribute_id integer := data.get_attribute_id('content');

  v_master_group_id integer := data.get_object_id('master');
begin
  -- создаём новый чат
  insert into data.objects(class_id) values (v_chat_class_id) returning id, code into v_chat_id;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_chat_id, v_subtitle_attribute_id, to_jsonb(in_chat_subtitle), null),
  (v_chat_id, v_is_visible_attribute_id, jsonb 'true', v_chat_id),
  (v_chat_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (v_chat_id, v_content_attribute_id, jsonb '[]', null);

  return v_chat_id;
end;
$$
language plpgsql;
