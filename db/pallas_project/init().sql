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
  ('system_chat_id', 'Идентификатор чата для обсуждения объекта', 'system', null, true);

  -- Создадим актора по умолчанию
  v_default_actor_id :=
    pallas_project.create_object(
      'anonymous',
      null,
      jsonb '{
        "title": "Гость",
        "is_visible": true,
        "actions_function": "pallas_project.actgenerator_anonymous",
        "template": {"title": "title", "groups": [{"code": "group1", "actions": ["create_random_person"]}]}}',
      null);

  -- Логин по умолчанию
  insert into data.logins default values returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_default_actor_id);

  insert into data.params(code, value, description) values
  ('default_login_id', to_jsonb(v_default_login_id), 'Идентификатор логина по умолчанию'),
  ('images_url', jsonb '"http://localhost:8000/images/"', 'Абсолютный или относительный URL к папке с изображениями, загружаемыми на сервер'),
  ('first_names', to_jsonb(string_to_array('Джон Джек Пол Джордж Билл Кевин Уильям Кристофер Энтони Алекс Джош Томас Фред Филипп Джеймс Брюс Питер Рональд Люк Энди Антонио Итан Сэм Марк Карл Роберт'||
  ' Эльза Лидия Лия Роза Кейт Тесса Рэйчел Амали Шарлотта Эшли София Саманта Элоиз Талия Молли Анна Виктория Мария Натали Келли Ванесса Мишель Элизабет Кимберли Кортни Лоис Сьюзен Эмма', ' ')), 'Список имён'),
  ('last_names', to_jsonb(string_to_array('Янг Коннери Питерс Паркер Уэйн Ли Максуэлл Калвер Кэмерон Альба Сэндерсон Бэйли Блэкшоу Браун Клеменс Хаузер Кендалл Патридж Рой Сойер Стоун Фостер Хэнкс Грегг'||
  ' Флинн Холл Винсон Уайтинг Хасси Хейвуд Стивенс Робинсон Йорк Гудман Махони Гордон Вуд Рид Грэй Тодд Иствуд Брукс Бродер Ховард Смит Нельсон Синклер Мур Тернер Китон Норрис', ' ')), 'Список фамилий');

  -- Также для работы нам понадобится объект меню
  perform pallas_project.create_object(
    'menu',
    null,
    jsonb '{
      "is_visible": true,
      "actions_function": "pallas_project.actgenerator_menu",
      "template": {"groups": [{"code": "menu_group1", "actions": ["login", "statuses", "debatles", "chats", "all_chats", "logout"]}]}}',
    null);

  -- И пустой список уведомлений
  perform pallas_project.create_object(
    'notifications',
    null,
    jsonb '{
      "is_visible": true,
      "content": []}',
    null);

  -- Создадим объект для страницы 404
  declare
    v_not_found_object_id integer;
  begin
    insert into data.attributes(code, description, type, card_type, value_description_function, can_be_overridden)
    values('not_found_description', 'Текст на странице 404', 'normal', 'full', 'pallas_project.vd_not_found_description', true);

    v_not_found_object_id :=
      pallas_project.create_object(
        'not_found',
        null,
        jsonb '{
          "type": "not_found",
          "is_visible": true,
          "title": "404",
          "subtitle": "Not found",
          "template": {"title": "title", "subtitle": "subtitle", "groups": [{"code": "general", "attributes": ["not_found_description"]}]},
          "not_found_description": null}',
        null);

    insert into data.params(code, value, description)
    values('not_found_object_id', to_jsonb(v_not_found_object_id), 'Идентификатор объекта, отображаемого в случае, если актору недоступен какой-то объект (ну или он реально не существует)');
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
  perform pallas_project.init_economics();
end;
$$
language plpgsql;
