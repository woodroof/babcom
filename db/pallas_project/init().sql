-- drop function pallas_project.init();

create or replace function pallas_project.init()
returns void
volatile
as
$$
declare
  v_default_actor_id integer;
  v_default_login_id integer;
begin
  insert into data.attributes(code, description, type, card_type, can_be_overridden) values
  ('description', 'Текстовый блок с развёрнутым описанием объекта, string', 'normal', 'full', true),
  ('mini_description', 'Текстовый блок с коротким описанием объекта, string', 'normal', 'mini', true),
  ('force_object_diff', 'Атрибут для принудительной генерации diff''а, integer', 'hidden', null, false),
  ('system_is_master_object', 'Мастерский персонаж, boolean', 'system', null, false);

  -- Создадим актора по умолчанию
  v_default_actor_id :=
    data.create_object(
      'anonymous',
      jsonb '[
        {"code": "title", "value": "Гость"},
        {"code": "is_visible", "value": true, "value_object_code": "anonymous"},
        {"code": "actions_function", "value": "pallas_project.actgenerator_anonymous"},
        {"code": "template", "value": {"title": "title", "groups": [{"code": "group1", "actions": ["create_random_person"]}]}}
      ]');

  -- Логин по умолчанию
  insert into data.logins default values returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_default_actor_id);

  insert into data.params(code, value, description) values
  ('default_login_id', to_jsonb(v_default_login_id), 'Идентификатор логина по умолчанию'),
  ('images_url', jsonb '"http://localhost:8000/images/"', 'Абсолютный или относительный URL к папке с изображениями, загружаемыми на сервер'),
  ('year', jsonb '2340', 'Год событий игры'),
  ('objects_url', jsonb '"https://petrosha.github.io/pallas/#/"', 'Адрес для ссылок на объекты'),
  ('first_names', to_jsonb(string_to_array('Джон Джек Пол Джордж Билл Кевин Уильям Кристофер Энтони Алекс Джош Томас Фред Филипп Джеймс Брюс Питер Рональд Люк Энди Антонио Итан Сэм Марк Карл Роберт'||
  ' Эльза Лидия Лия Роза Кейт Тесса Рэйчел Амали Шарлотта Эшли София Саманта Элоиз Талия Молли Анна Виктория Мария Натали Келли Ванесса Мишель Элизабет Кимберли Кортни Лоис Сьюзен Эмма', ' ')), 'Список имён'),
  ('last_names', to_jsonb(string_to_array('Янг Коннери Питерс Паркер Уэйн Ли Максуэлл Калвер Кэмерон Альба Сэндерсон Бэйли Блэкшоу Браун Клеменс Хаузер Кендалл Патридж Рой Сойер Стоун Фостер Хэнкс Грегг'||
  ' Флинн Холл Винсон Уайтинг Хасси Хейвуд Стивенс Робинсон Йорк Гудман Махони Гордон Вуд Рид Грэй Тодд Иствуд Брукс Бродер Ховард Смит Нельсон Синклер Мур Тернер Китон Норрис', ' ')), 'Список фамилий');

  -- Также для работы нам понадобится объект меню
  perform data.create_object(
    'menu',
    jsonb '{
      "is_visible": true,
      "actions_function": "pallas_project.actgenerator_menu",
      "force_object_diff": 0,
      "template": {
        "groups": [
          {"code": "menu_notifications", "actions": ["notifications"]},
          {"code": "menu_lottery", "actions": ["lottery"]},
          {"code": "menu_personal", "actions": ["login", "profile", "transactions", "statuses", "next_statuses", "med_health", "chats", "documents", "medicine", "my_contracts", "my_organizations", "blogs", "claims", "important_notifications", "med_drugs"]},
          {"code": "menu_social", "actions": ["news", "all_chats", "debatles", "master_chats"]},
          {"code": "menu_info", "actions": ["all_contracts", "persons", "districts", "organizations"]},
          {"code": "menu_finish_game", "actions": ["finish_game"]},
          {"code": "menu_logout", "actions": ["logout"]}
        ]
      }
    }');

  -- И пустой список уведомлений
  perform data.create_class(
    'notification_list',
    jsonb '{
      "title": "Уведомления",
      "template": {"title": "title", "groups": [{"code": "group", "actions": ["clear_notifications"]}]},
      "actions_function": "pallas_project.actgenerator_notifications",
      "list_actions_function": "pallas_project.actgenerator_notifications_content",
      "list_element_function": "pallas_project.lef_notifications",
      "independent_from_actor_list_elements": true,
      "independent_from_object_list_elements": true
    }');
  perform data.create_object(
    'notifications',
    jsonb '{}');

  -- Создадим объект для страницы 404
  declare
    v_not_found_object_id integer;
  begin
    insert into data.attributes(code, description, type, card_type, value_description_function, can_be_overridden)
    values('not_found_description', 'Текст на странице 404', 'normal', 'full', 'pallas_project.vd_not_found_description', true);

    v_not_found_object_id :=
      data.create_object(
        'not_found',
        jsonb '{
          "type": "not_found",
          "is_visible": true,
          "title": "404",
          "subtitle": "Not found",
          "template": {"title": "title", "subtitle": "subtitle", "groups": [{"code": "general", "attributes": ["not_found_description"]}]},
          "not_found_description": null
        }');

    insert into data.params(code, value, description)
    values('not_found_object_id', to_jsonb(v_not_found_object_id), 'Идентификатор объекта, отображаемого в случае, если актору недоступен какой-то объект (ну или он реально не существует)');
  end;

  insert into data.actions(code, function) values
  ('act_open_object', 'pallas_project.act_open_object'),
  ('login', 'pallas_project.act_login'),
  ('logout', 'pallas_project.act_logout'),
  ('go_back', 'pallas_project.act_go_back'),
  ('create_random_person', 'pallas_project.act_create_random_person'),
  ('remove_notification', 'pallas_project.act_remove_notification'),
  ('clear_notifications', 'pallas_project.act_clear_notifications'),
  ('finish_game', 'pallas_project.act_finish_game');

  -- Базовые классы
  perform data.create_class(
    'notification',
    jsonb '{
      "type": "notification",
      "touch_function": "pallas_project.touch_notification",
      "mini_card_template": {"groups": [{"code": "group", "attributes": ["title"], "actions": ["remove_notification"]}]}
    }');

  perform pallas_project.init_groups();
  perform pallas_project.init_economics();
  perform pallas_project.init_finances();
  perform pallas_project.init_districts();
  perform pallas_project.init_medicine();
  perform pallas_project.init_persons();
  perform pallas_project.init_claims();
  perform pallas_project.init_organizations();
  perform pallas_project.init_organization_roles();
  perform pallas_project.init_contracts();
  perform pallas_project.init_debatles();
  perform pallas_project.init_messenger();
  perform pallas_project.init_person_list();
  perform pallas_project.init_documents();
  perform pallas_project.init_lottery();
  perform pallas_project.init_blogs();
  perform pallas_project.init_cycles();
end;
$$
language plpgsql;
