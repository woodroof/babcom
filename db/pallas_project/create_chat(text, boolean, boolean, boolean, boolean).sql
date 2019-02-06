-- drop function pallas_project.create_chat(text, boolean, boolean, boolean, boolean);

create or replace function pallas_project.create_chat(in_chat_title text, in_can_invite boolean, in_can_leave boolean, in_can_mute boolean, in_can_rename boolean)
returns integer
volatile
as
$$
declare
  v_chat_id  integer;
  v_chat_class_id integer := data.get_class_id('chat');

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_system_chat_can_invite_attribute_id integer := data.get_attribute_id('system_chat_can_invite');
  v_system_chat_can_leave_attribute_id integer := data.get_attribute_id('system_chat_can_leave');
  v_system_chat_can_mute_attribute_id integer := data.get_attribute_id('system_chat_can_mute');
  v_system_chat_can_rename_attribute_id integer := data.get_attribute_id('system_chat_can_rename');

  v_master_group_id integer := data.get_object_id('master');
begin
  -- создаём новый чат
  insert into data.objects(class_id) values (v_chat_class_id) returning id, code into v_chat_id;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_chat_id, v_title_attribute_id, to_jsonb(in_chat_title), null),
  (v_chat_id, v_is_visible_attribute_id, jsonb 'true', v_chat_id),
  (v_chat_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (v_chat_id, v_content_attribute_id, jsonb '[]', null);

  if not in_can_invite then
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_chat_id, v_system_chat_can_invite_attribute_id, jsonb 'false');
  end if;

  if not in_can_leave then
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_chat_id, v_system_chat_can_leave_attribute_id, jsonb 'false');
  end if;

  if not in_can_mute then
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_chat_id, v_system_chat_can_mute_attribute_id, jsonb 'false');
  end if;

  if not in_can_rename then
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_chat_id, v_system_chat_can_rename_attribute_id, jsonb 'false');
  end if;


  return v_chat_id;
end;
$$
language plpgsql;
