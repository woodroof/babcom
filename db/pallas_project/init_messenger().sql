-- drop function pallas_project.init_messenger();

create or replace function pallas_project.init_messenger()
returns void
volatile
as
$$
declare
  v_type_attribute_id integer := data.get_attribute_id('type');
  v_independent_from_actor_list_elements_attribute_id integer := data.get_attribute_id('independent_from_actor_list_elements');
  v_independent_from_object_list_elements_attribute_id integer := data.get_attribute_id('independent_from_object_list_elements');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_actions_function_attribute_id integer := data.get_attribute_id('actions_function');
  v_template_attribute_id integer := data.get_attribute_id('template');
  v_full_card_function_attribute_id integer := data.get_attribute_id('full_card_function');
  v_mini_card_function_attribute_id integer := data.get_attribute_id('mini_card_function');
  v_list_element_function_attribute_id integer := data.get_attribute_id('list_element_function');
  v_temporary_object_attribute_id integer := data.get_attribute_id('temporary_object');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_priority_attribute_id integer := data.get_attribute_id('priority');

  v_master_group_id integer := data.get_object_id('master');

  v_chats_id integer;
  v_master_chats_id integer;
  v_chat_class_id integer;
  v_message_class_id integer;
  v_chat_person_list_class_id integer;

  v_system_chat_can_invite_attribute_id integer;
  v_system_chat_can_leave_attribute_id integer;
  v_system_chat_can_mute_attribute_id integer;
  v_system_chat_can_rename_attribute_id integer;
  v_chat_id integer;
begin
  -- Атрибуты 
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  --для сообщений
  ('message_text', null, 'Текст сообщения', 'normal', null, null, false),
  ('system_message_sender', null, 'id объекта-отправителя сообщения', 'system', null, null, false),
  ('system_message_time', null, 'Дата и время отправки сообщения', 'system', null, null, false),
  -- для чатов
  ('system_chat_can_invite', null, 'Возможность пригласить кого-то в чат', 'system', null, null, false),
  ('system_chat_can_leave', null, 'Возможность покинуть чат', 'system', null, null, false),
  ('system_chat_can_mute', null, 'Возможность убрать уведомления о новых сообщениях', 'system', null, null, false),
  ('system_chat_can_rename', null, 'Возможность переименовать чат', 'system', null, null, false),
  ('system_chat_cant_write', null, 'Невозможность писать в чат', 'system', null, null, false),
  ('system_chat_cant_see_members', null, 'Невозможность смотреть список участников', 'system', null, null, false),
  ('chat_is_mute', null, 'Признак отлюченного уведомления о новых сообщениях', 'normal', 'full', 'pallas_project.vd_chat_is_mute', true),
  ('chat_unread_messages', 'Непрочитанных сообщений', 'Количество непрочитанных сообщений', 'normal', 'mini', null, true),
  ('system_chat_length', null , 'Количество сообщений', 'system', null, null, false),
  ('system_chat_is_renamed', null, 'Признак, что чат был переименован', 'system', null, null, false),
  ('system_chat_parent_list', null, 'Список, в котором надо двигать чат вверх', 'system', null, null, false),
    -- для временных объектов для изменения участников
  ('chat_person_list_persons', 'Сейчас участвуют', 'Список участников чата', 'normal', 'full', null, false),
  ('chat_person_list_content_label', null, 'Заголовок списка добавляемых участников', 'normal', null, null, true);

  v_system_chat_can_invite_attribute_id := data.get_attribute_id('system_chat_can_invite');
  v_system_chat_can_leave_attribute_id := data.get_attribute_id('system_chat_can_leave');
  v_system_chat_can_mute_attribute_id := data.get_attribute_id('system_chat_can_mute');
  v_system_chat_can_rename_attribute_id := data.get_attribute_id('system_chat_can_rename');

  -- Объект со списком чатов
  insert into data.objects(code) values('chats') returning id into v_chats_id;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_chats_id, v_type_attribute_id, jsonb '"chats"', null),
  (v_chats_id, v_independent_from_actor_list_elements_attribute_id, jsonb 'true', null),
  (v_chats_id, v_independent_from_object_list_elements_attribute_id, jsonb 'true', null),
  (v_chats_id, v_is_visible_attribute_id, jsonb 'true', null),
  (v_chats_id, v_title_attribute_id, jsonb '"Чаты"', null),
  (v_chats_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_chats"', null),
  (v_chats_id, v_list_element_function_attribute_id, jsonb '"pallas_project.lef_chats"', null),
  (v_chats_id, v_content_attribute_id, jsonb '[]', null),
  (
    v_chats_id,
    v_template_attribute_id,
    jsonb '{
      "title": "title",
      "subtitle": "subtitle",
      "groups": [
        {"code": "chats_group1", "attributes": ["description"], "actions": ["create_chat"]}
      ]
    }',
  null);

  -- Объект со списком всех чатов (для мастеров)
  insert into data.objects(code) values('all_chats') returning id into v_chats_id;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_chats_id, v_type_attribute_id, jsonb '"chats"', null),
  (v_chats_id, v_independent_from_actor_list_elements_attribute_id, jsonb 'true', null),
  (v_chats_id, v_independent_from_object_list_elements_attribute_id, jsonb 'true', null),
  (v_chats_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (v_chats_id, v_title_attribute_id, jsonb '"Все игровые чаты"', null),
  (v_chats_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_chats"', null),
  (v_chats_id, v_list_element_function_attribute_id, jsonb '"pallas_project.lef_chats"', null),
  (v_chats_id, v_content_attribute_id, jsonb '[]', null),
  (
    v_chats_id,
    v_template_attribute_id,
    jsonb '{
      "title": "title",
      "subtitle": "subtitle",
      "groups": [
        {"code": "chats_group1", "attributes": ["description"], "actions": ["create_chat"]}
      ]
    }',
    null
  );

  -- Объект со списком мастерских чатов
  insert into data.objects(code) values('master_chats') returning id into v_master_chats_id;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_master_chats_id, v_type_attribute_id, jsonb '"chats"', null),
  (v_master_chats_id, v_independent_from_actor_list_elements_attribute_id, jsonb 'true', null),
  (v_master_chats_id, v_independent_from_object_list_elements_attribute_id, jsonb 'true', null),
  (v_master_chats_id, v_is_visible_attribute_id, jsonb 'true', null),
  (v_master_chats_id, v_title_attribute_id, jsonb '"Общение с мастерами"', null),
  (v_master_chats_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_chats"', null),
  (v_master_chats_id, v_list_element_function_attribute_id, jsonb '"pallas_project.lef_chats"', null),
  (v_master_chats_id, v_content_attribute_id, jsonb '[]', null),
  (
    v_master_chats_id,
    v_template_attribute_id,
    jsonb '{
      "title": "title",
      "subtitle": "subtitle",
      "groups": [
        {"code": "chats_group1", "attributes": ["description"], "actions": ["create_chat"]}
      ]
    }',
    null
  );

  -- Объект-класс для чата
  insert into data.objects(code, type) values('chat', 'class') returning id into v_chat_class_id;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_chat_class_id, v_type_attribute_id, jsonb '"chat"', null),
  (v_chat_class_id, v_independent_from_actor_list_elements_attribute_id, jsonb 'true', null),
  (v_chat_class_id, v_independent_from_object_list_elements_attribute_id, jsonb 'true', null),
  (v_chat_class_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (v_chat_class_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_chat"', null),
  (v_chat_class_id, v_list_element_function_attribute_id, jsonb '"pallas_project.lef_do_nothing"', null),
  (v_chat_class_id, v_system_chat_can_invite_attribute_id, jsonb 'true', null),
  (v_chat_class_id, v_system_chat_can_leave_attribute_id, jsonb 'true', null),
  (v_chat_class_id, v_system_chat_can_mute_attribute_id, jsonb 'true', null),
  (v_chat_class_id, v_system_chat_can_rename_attribute_id, jsonb 'true', null),
  (v_chat_class_id, v_priority_attribute_id, jsonb '100', null),
  (
    v_chat_class_id,
    v_template_attribute_id,
    jsonb '{
      "title": "title",
      "subtitle": "subtitle",
      "groups": [
        {
          "code": "chats_group1",
          "attributes": ["chat_is_mute", "chat_unread_messages"],
          "actions": ["chat_add_person", "chat_leave", "chat_mute", "chat_rename", "chat_enter"]
        },
        {
          "code": "chat_group2",
          "name": "Настройки чата",
          "actions": ["chat_change_can_invite", "chat_change_can_leave", "chat_change_can_mute", "chat_change_can_rename"]
        },
        {
          "code": "chat_group3",
          "actions": ["chat_write"]
        }
      ]
    }',
  null);

  -- Объект-класс для сообщения
  insert into data.objects(code, type) values('message', 'class') returning id into v_message_class_id;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_message_class_id, v_type_attribute_id, jsonb '"message"', null),
  (v_message_class_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (
    v_message_class_id,
    v_template_attribute_id,
    jsonb '{
      "groups": [
        {"code": "message_group1", "attributes": ["title", "message_text"]}
      ]
    }',
  null);

  -- Объект-класс для списков персон для редактирования участников чата
  insert into data.objects(code, type) values('chat_person_list', 'class') returning id into v_chat_person_list_class_id;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_chat_person_list_class_id, v_type_attribute_id, jsonb '"chat_person_list"', null),
  (v_chat_person_list_class_id, v_independent_from_actor_list_elements_attribute_id, jsonb 'true', null),
  (v_chat_person_list_class_id, v_independent_from_object_list_elements_attribute_id, jsonb 'true', null),
  (v_chat_person_list_class_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (v_chat_person_list_class_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_chat_temp_person_list"', null),
  (v_chat_person_list_class_id, v_list_element_function_attribute_id, jsonb '"pallas_project.lef_chat_temp_person_list"', null),
  (
    v_chat_person_list_class_id,
    v_template_attribute_id,
    jsonb '{
      "title": "title",
      "subtitle": "subtitle",
      "groups": [
        {"code": "group1", "actions": ["chat_add_person_back"]},
        {"code": "group2", "attributes": ["chat_person_list_persons", "chat_person_list_content_label"]}
      ]
    }', 
  null);

  -- Чат-бот
  perform data.create_object(
  'chat_bot',
  jsonb '{"title": "Чат-бот"}');

  -- Мастерские чаты
  declare
    v_person_id integer;
    v_master_person_id integer;
    v_masters integer[] := pallas_project.get_group_members('master');
    v_important integer;
    v_important_chat_id integer;
    v_redirect_attribute_id integer := data.get_attribute_id('redirect');
  begin
    -- Чат для мастеров и уведомлений
    v_chat_id := pallas_project.create_chat(
    'master_chat',
    jsonb '{
      "content": [],
      "title": "Мастера и уведомления",
      "system_chat_is_renamed": true,
      "system_chat_can_invite": false,
      "system_chat_can_leave": false,
      "system_chat_can_mute": false,
      "system_chat_parent_list": "master_chats"
    }');

    for v_master_person_id in (select * from unnest(v_masters))
    loop
      perform data.add_object_to_object(v_master_person_id, v_chat_id);
    end loop;
    perform pallas_project.change_chat_person_list_on_person(v_chat_id, null, true);

    perform pp_utils.list_prepend_and_notify(v_master_chats_id, data.get_object_code(v_chat_id), v_master_group_id, v_master_group_id);

    -- Чаты для каждого игрового персонажа
    -- Объект для меню "Важные уведомления"
    v_important := data.create_object(
      'important_notifications',
      jsonb_build_object(
        'title', 'Важные уведомления',
        'is_visible', true
      ));
    for v_person_id in (select * from unnest(pallas_project.get_group_members('all_person')))
    loop
    -- чат с мастерами
      v_chat_id := pallas_project.create_chat(
      null,
      jsonb_build_object(
        'content', jsonb '[]',
        'title', 'Мастерский для ' || json.get_string(data.get_attribute_value(v_person_id, v_title_attribute_id)),
        'system_chat_is_renamed', true,
        'system_chat_can_invite', false,
        'system_chat_can_leave', false,
        'system_chat_can_mute', false,
        'system_chat_can_rename', false,
        'system_chat_parent_list', 'master_chats'
      ));

      perform data.add_object_to_object(v_person_id, v_chat_id);
      for v_master_person_id in (select * from unnest(v_masters))
      loop
        perform data.add_object_to_object(v_master_person_id, v_chat_id);
      end loop;
      perform pallas_project.change_chat_person_list_on_person(v_chat_id, null, true);

      perform pp_utils.list_prepend_and_notify(v_master_chats_id, data.get_object_code(v_chat_id), v_master_group_id, v_master_group_id);
      perform pp_utils.list_prepend_and_notify(v_master_chats_id, data.get_object_code(v_chat_id), v_person_id, v_person_id);

      -- чат для важных уведомлений
      v_important_chat_id := pallas_project.create_chat(
      null,
      jsonb_build_object(
        'content', jsonb '[]',
        'title', 'Важные уведомления',
        'system_chat_is_renamed', true,
        'system_chat_can_invite', false,
        'system_chat_can_leave', false,
        'system_chat_can_mute', false,
        'system_chat_can_rename', false,
        'system_chat_cant_write', true,
        'system_chat_cant_see_members', true
      ));

      insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
      (v_important, v_redirect_attribute_id, to_jsonb(v_important_chat_id), v_person_id);

      perform data.add_object_to_object(v_person_id, v_important_chat_id);
      perform pallas_project.change_chat_person_list_on_person(v_important_chat_id, null, false);
    end loop;
  end;

  insert into data.actions(code, function) values
  ('create_chat', 'pallas_project.act_create_chat'),
  ('chat_write', 'pallas_project.act_chat_write'),
  ('chat_leave','pallas_project.act_chat_leave'),
  ('chat_mute','pallas_project.act_chat_mute'),
  ('chat_rename','pallas_project.act_chat_rename'),
  ('chat_enter','pallas_project.act_chat_enter'),
  ('chat_change_settings','pallas_project.act_chat_change_settings');
end;
$$
language plpgsql;
