-- drop function pallas_project.create_chats_with_master_character(integer, text[]);

create or replace function pallas_project.create_chats_with_master_character(in_master_character_id integer, in_player_codes text[])
returns void
volatile
as
$$
-- Не для использования на игре, т.к. обновляет атрибуты напрямую, без уведомлений и блокировок!
declare
  v_master_character_code text := data.get_object_code(in_master_character_id);
  v_chat_id integer;
  v_player record;
  v_all_chats_id integer := data.get_object_id('all_chats');
  v_title_attr_id integer := data.get_attribute_id('title');
  v_master_character_title text := json.get_string(data.get_attribute_value(in_master_character_id, v_title_attr_id));
  v_masters integer[] := pallas_project.get_group_members('master');
  v_master_id integer;
begin
  for v_player in
  (
    select data.get_object_id(value) as id, value as code
    from unnest(in_player_codes) a(value)
  )
  loop
    v_chat_id :=
      pallas_project.create_chat(
        null,
        format(
          '{
            "content": [],
            "title": "%s, %s",
            "system_chat_is_renamed": true,
            "system_chat_can_invite": false,
            "system_chat_can_leave": false,
            "system_chat_can_mute": false,
            "system_chat_can_rename": false,
            "system_chat_parent_list": "chats"
          }',
          v_master_character_title,
          json.get_string(data.get_attribute_value(v_player.id, v_title_attr_id)))::jsonb);
    perform data.add_object_to_object(in_master_character_id, v_chat_id);
    perform data.add_object_to_object(v_player.id, v_chat_id);

    for v_master_id in
    (
      select value
      from unnest(v_masters) a(value)
    )
    loop
      perform data.add_object_to_object(v_master_id, v_chat_id);
    end loop;

    perform pp_utils.list_prepend_and_notify(data.get_object_id(v_player.code || '_chats'), v_chat_id, null);
    perform pp_utils.list_prepend_and_notify(data.get_object_id(v_master_character_code || '_chats'), v_chat_id, null);
    perform pp_utils.list_prepend_and_notify(v_all_chats_id, v_chat_id, null);
  end loop;
end;
$$
language plpgsql;
