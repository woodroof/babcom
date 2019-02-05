-- drop function job_test_project.init();

create or replace function job_test_project.init()
returns void
volatile
as
$$
declare
  v_type_attribute_id integer := data.get_attribute_id('type');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_actions_function_attribute_id integer := data.get_attribute_id('actions_function');
  v_template_attribute_id integer := data.get_attribute_id('template');

  v_menu_id integer;
  v_notifications_id integer;

  v_description_attribute_id integer;
  v_state_attribute_id integer;
  v_object_id integer;
  v_default_login_id integer;
begin
  -- Пустой объект меню
  insert into data.objects(code) values('menu') returning id into v_menu_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_menu_id, v_type_attribute_id, jsonb '"menu"'),
  (v_menu_id, v_is_visible_attribute_id, jsonb 'true');

  -- Пустой список уведомлений
  insert into data.objects(code) values('notifications') returning id into v_notifications_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_notifications_id, v_type_attribute_id, jsonb '"notifications"'),
  (v_notifications_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_notifications_id, v_content_attribute_id, jsonb '[]');

  -- Атрибуты
  insert into data.attributes(code, type, card_type, can_be_overridden)
  values ('description', 'normal', null, true)
  returning id into v_description_attribute_id;

  insert into data.attributes(code, type, card_type, can_be_overridden)
  values ('state', 'hidden', null, true)
  returning id into v_state_attribute_id;

  -- Действия
  insert into data.actions(code, function) values
  ('start_countdown', 'job_test_project.start_countdown_action');

  -- И сам объект
  insert into data.objects(code) values('object') returning id into v_object_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_object_id, v_type_attribute_id, jsonb '"object"'),
  (v_object_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_object_id, v_state_attribute_id, jsonb '"state1"'),
  (v_object_id, v_description_attribute_id, jsonb '"Обратный отсчёт!"'),
  (v_object_id, v_template_attribute_id, jsonb '{"groups": [{"code": "general", "attributes": ["description"], "actions": ["action"]}]}'),
  (v_object_id, v_actions_function_attribute_id, jsonb '"job_test_project.start_countdown_action_generator"');

  -- Логин по умолчанию
  insert into data.logins(code) values('default_login') returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_object_id);

  insert into data.params(code, value, description)
  values('default_login_id', to_jsonb(v_default_login_id), 'Идентификатор логина по умолчанию');
end;
$$
language plpgsql;
