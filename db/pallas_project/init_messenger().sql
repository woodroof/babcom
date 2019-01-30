-- drop function pallas_project.init_messenger();

create or replace function pallas_project.init_messenger()
returns void
volatile
as
$$
declare
  v_type_attribute_id integer := data.get_attribute_id('type');
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
  v_chat_class_id integer;
  v_message_class_id integer;
  v_chat_temp_person_list_class_id integer;

  v_system_chat_can_invite_attribute_id integer;
  v_system_chat_can_leave_attribute_id integer;
  v_system_chat_can_mute_attribute_id integer;
  v_system_chat_can_rename_attribute_id integer;

begin
  -- Атрибуты 
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  --для сообщений
  ('message_text', null, 'Текст сообщения', 'normal', null, null, false),
  ('system_message_sender', null, 'id объекта-отправителя сообщения', 'system', null, null, false),
  ('system_message_time', null, 'Дата и время отправки сообщения', 'system', null, null, false),
  -- для чатов
  ('chat_persons', null, 'Участники чата', 'normal', 'full', null, false),
  ('system_chat_can_invite', null, 'Возможность пригласить кого-то в чат', 'system', null, null, true),
  ('system_chat_can_leave', null, 'Возможность покинуть чат', 'system', null, null, true),
  ('system_chat_can_mute', null, 'Возможность Убрать уведомления о новых сообщениях', 'system', null, null, true),
  ('system_chat_can_rename', null, 'Возможность переименовать чат', 'system', null, null, true),
  ('system_chat_is_mute', null, 'Признак отлюченного уведомления о новых сообщениях', 'system', null, null, true),
  ('system_chat_last_message_time', null, 'Дата последнего собщения', 'system', null, null, false),
  -- для временных объектов для изменения участников
  ('chat_temp_person_list_persons', 'Сейчас участвуют:', 'Список участников чата', 'normal', 'full', null, false),
  ('system_chat_temp_person_list_chat_id', null, 'Идентификатор изменяемого чата', 'system', null, null, false);

  v_system_chat_can_invite_attribute_id := data.get_attribute_id('system_chat_can_invite');
  v_system_chat_can_leave_attribute_id := data.get_attribute_id('system_chat_can_leave');
  v_system_chat_can_mute_attribute_id := data.get_attribute_id('system_chat_can_mute');
  v_system_chat_can_rename_attribute_id := data.get_attribute_id('system_chat_can_rename');

  -- Объект со списком чатов
  insert into data.objects(code) values('chats') returning id into v_chats_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_chats_id, v_type_attribute_id, jsonb '"chats"'),
  (v_chats_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_chats_id, v_title_attribute_id, jsonb '"Чаты"'),
--  (v_chats_id, v_full_card_function_attribute_id, jsonb '"pallas_project.fcard_debatles"'),
  (v_chats_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_chats"'),
  (v_chats_id, v_content_attribute_id, jsonb '[]'),
  (v_chats_id, v_template_attribute_id, jsonb_build_object('groups', array[format(
                                          '{"code": "%s", "attributes": ["%s"], "actions": ["%s"]}',
                                          'chats_group1',
                                          'description',
                                          'create_chat')::jsonb]));

  -- Объект со списком всех чатов (для мастеров)
  insert into data.objects(code) values('all_chats') returning id into v_chats_id;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_chats_id, v_type_attribute_id, jsonb '"all_chats"', null),
  (v_chats_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (v_chats_id, v_title_attribute_id, jsonb '"Все чаты"', null),
--  (v_chats_id, v_full_card_function_attribute_id, jsonb '"pallas_project.fcard_debatles"', null),
  (v_chats_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_chats"', null),
  (v_chats_id, v_content_attribute_id, jsonb '[]', null),
  (v_chats_id, v_template_attribute_id, jsonb_build_object('groups', array[format(
                                          '{"code": "%s", "attributes": ["%s"], "actions": ["%s"]}',
                                          'chats_group1',
                                          'description',
                                          'create_chat')::jsonb]), null);

  -- Объект-класс для чата
  insert into data.objects(code, type) values('chat', 'class') returning id into v_chat_class_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_chat_class_id, v_type_attribute_id, jsonb '"chat"'),
  --(v_chat_class_id, v_full_card_function_attribute_id, jsonb '"pallas_project.fcard_debatle"'),
  --(v_chat_class_id, v_mini_card_function_attribute_id, jsonb '"pallas_project.mcard_debatle"'),
  (v_chat_class_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_chat"'),
  (v_chat_class_id, v_priority_attribute_id, jsonb '100'),
  (v_chat_class_id, v_system_chat_can_invite_attribute_id, jsonb 'true'),
  (v_chat_class_id, v_system_chat_can_leave_attribute_id, jsonb 'true'),
  (v_chat_class_id, v_system_chat_can_mute_attribute_id, jsonb 'true'),
  (v_chat_class_id, v_system_chat_can_rename_attribute_id, jsonb 'true'),
  (v_chat_class_id, v_template_attribute_id, jsonb_build_object('groups', array[format(
                                                      '{"code": "%s", "attributes": ["%s"], 
                                                                      "actions": ["%s", "%s", "%s"]}',
                                                      'chat_group1',
                                                      'chat_persons',
                                                      'chat_add_person',
                                                      'chat_leave',
                                                      'chat_mute')::jsonb,
                                                      format(
                                                      '{"code": "%s", "actions": ["%s"]}',
                                                      'chat_group2',
                                                      'chat_write')::jsonb]));

  -- Объект-класс для сообщения
  insert into data.objects(code, type) values('message', 'class') returning id into v_message_class_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_message_class_id, v_type_attribute_id, jsonb '"message"'),
  --(v_message_class_id, v_full_card_function_attribute_id, jsonb '"pallas_project.fcard_debatle"'),
  --(v_message_class_id, v_mini_card_function_attribute_id, jsonb '"pallas_project.mcard_debatle"'),
  --(v_message_class_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_debatle"'),
  (v_message_class_id, v_template_attribute_id, jsonb_build_object('groups', array[format(
                                                      '{"code": "%s", "attributes": ["%s"]}',
                                                      'message_group1',
                                                      'message_text')::jsonb]));

  -- Объект-класс для временных списков персон для редактирования участников чата
  insert into data.objects(code, type) values('chat_temp_person_list', 'class') returning id into v_chat_temp_person_list_class_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_chat_temp_person_list_class_id, v_type_attribute_id, jsonb '"chat_temp_person_list"'),
--  (v_chat_temp_person_list_class_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_debatle_temp_person_list"'),
--  (v_chat_temp_person_list_class_id, v_list_element_function_attribute_id, jsonb '"pallas_project.lef_debatle_temp_person_list"'),
  (v_chat_temp_person_list_class_id, v_temporary_object_attribute_id, jsonb 'true'),
  (v_chat_temp_person_list_class_id, v_template_attribute_id, jsonb_build_object('groups', format(
                                                      '[{"code": "%s", "actions": ["%s"]},{"code": "%s", "attributes": ["%s"]}]',
                                                      'group1',
                                                      'chat_add_person_back',
                                                      'group2',
                                                      'chat_temp_person_list_persons')::jsonb));

  insert into data.actions(code, function) values
  ('create_chat', 'pallas_project.act_create_chat'),
  ('chat_write', 'pallas_project.act_chat_write'),
  ('chat_add_person','pallas_project.act_chat_add_person');

end;
$$
language plpgsql;
