-- drop function pallas_project.init();

create or replace function pallas_project.init()
returns void
volatile
as
$$
declare
  v_type_attribute_id integer := data.get_attribute_id('type');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_subtitle_attribute_id integer := data.get_attribute_id('subtitle');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_priority_attribute_id integer := data.get_attribute_id('priority');
  v_full_card_function_attribute_id integer := data.get_attribute_id('full_card_function');
  v_mini_card_function_attribute_id integer := data.get_attribute_id('mini_card_function');
  v_actions_function_attribute_id integer := data.get_attribute_id('actions_function');
  v_template_attribute_id integer := data.get_attribute_id('template');

  v_description_attribute_id integer;

  v_default_login_id integer;
  v_menu_id integer;
  v_notifications_id integer;
  v_test_id integer;

begin
  insert into data.attributes(code, description, type, card_type, can_be_overridden)
  values('description', 'Текстовый блок с развёрнутым описанием объекта, string', 'normal', 'full', true)
  returning id into v_description_attribute_id;

  -- Создадим актора по умолчанию
  insert into data.objects(code) values('anonymous') returning id into v_test_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_title_attribute_id, jsonb '"Гость"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id,'"pallas_project.actgenerator_anonymous"'),
  (v_test_id, v_template_attribute_id, jsonb_build_object('groups', array[format(
                                      '{"code": "%s", "actions": ["%s"]}',
                                      'group1',
                                      'create_random_person')::jsonb]));

  -- Логин по умолчанию
  insert into data.logins(code) values('default_login') returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_test_id);

  insert into data.params(code, value, description) values
  ('default_login_id', to_jsonb(v_default_login_id), 'Идентификатор логина по умолчанию'),
  ('first_names', to_jsonb(string_to_array('Джон Джек Пол Джордж Билл Кевин Уильям Кристофер Энтони Алекс Джош Томас Фред Филипп Джеймс Брюс Питер Рональд Люк Энди Антонио Итан Сэм Марк Карл Роберт'||
  ' Эльза Лидия Лия Роза Кейт Тесса Рэйчел Амали Шарлотта Эшли София Саманта Элоиз Талия Молли Анна Виктория Мария Натали Келли Ванесса Мишель Элизабет Кимберли Кортни Лоис Сьюзен Эмма', ' ')), 'Список имён'),
  ('last_names', to_jsonb(string_to_array('Янг Коннери Питерс Паркер Уэйн Ли Максуэлл Калвер Кэмерон Альба Сэндерсон Бэйли Блэкшоу Браун Клеменс Хаузер Кендалл Патридж Рой Сойер Стоун Фостер Хэнкс Грегг'||
  ' Флинн Холл Винсон Уайтинг Хасси Хейвуд Стивенс Робинсон Йорк Гудман Махони Гордон Вуд Рид Грэй Тодд Иствуд Брукс Бродер Ховард Смит Нельсон Синклер Мур Тернер Китон Норрис', ' ')), 'Список фамилий');

  -- Также для работы нам понадобится объект меню
  insert into data.objects(code) values('menu') returning id into v_menu_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_menu_id, v_type_attribute_id, jsonb '"menu"'),
  (v_menu_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_menu_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_menu"'),
  (v_menu_id, v_template_attribute_id, jsonb_build_object('groups', array[format(
                                      '{"code": "%s", "actions": ["%s", "%s", "%s", "%s", "%s"]}',
                                      'menu_group1',
                                      'login',
                                      'debatles',
                                      'chats',
                                      'all_chats',
                                      'logout')::jsonb]));

  -- И пустой список уведомлений
  insert into data.objects(code) values('notifications') returning id into v_notifications_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_notifications_id, v_type_attribute_id, jsonb '"notifications"'),
  (v_notifications_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_notifications_id, v_content_attribute_id, jsonb '[]');

  -- Создадим объект для страницы 404
  declare
    v_not_found_object_id integer;
    v_not_found_description_attribute_id integer;
  begin
    insert into data.objects(code) values('not_found') returning id into v_not_found_object_id;
    insert into data.params(code, value, description)
    values('not_found_object_id', to_jsonb(v_not_found_object_id), 'Идентификатор объекта, отображаемого в случае, если актору недоступен какой-то объект (ну или он реально не существует)');

    insert into data.attributes(code, description, type, card_type, value_description_function, can_be_overridden)
    values('not_found_description', 'Текст на странице 404', 'normal', 'full', 'pallas_project.vd_not_found_description', true)
    returning id into v_not_found_description_attribute_id;

    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_not_found_object_id, v_type_attribute_id, jsonb '"not_found"'),
    (v_not_found_object_id, v_is_visible_attribute_id, jsonb 'true'),
    (v_not_found_object_id, v_title_attribute_id, jsonb '"404"'),
    (v_not_found_object_id, v_subtitle_attribute_id, jsonb '"Not found"'),
    (v_not_found_object_id, v_template_attribute_id, jsonb '{"groups": [{"code": "general", "attributes": ["not_found_description"]}]}'),
    (v_not_found_object_id, v_not_found_description_attribute_id, null);
  end;

  insert into data.actions(code, function) values
  ('act_open_object', 'pallas_project.act_open_object'),
  ('login', 'pallas_project.act_login'),
  ('logout', 'pallas_project.act_logout'),
  ('go_back', 'pallas_project.act_go_back'),
  ('create_random_person', 'pallas_project.act_create_random_person');

  perform pallas_project.init_persons();
  perform pallas_project.init_debatles();
  perform pallas_project.init_messenger();
end;
$$
language plpgsql;
