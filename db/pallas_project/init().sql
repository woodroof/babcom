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
  v_system_person_name_attribute_id integer;
  v_person_state_attribute_id integer;
  v_person_occupation_attribute_id integer; 
  v_system_money_attribute_id integer;
  v_money_attribute_id integer;
  v_system_person_deposit_money_attribute_id integer;
  v_person_deposit_money_attribute_id integer;
  v_system_person_coin_attribute_id integer;
  v_person_coin_attribute_id integer;
  v_system_person_opa_rating_attribute_id integer;
  v_person_opa_rating_attribute_id integer;
  v_system_person_un_rating_attribute_id integer;
  v_person_un_rating_attribute_id integer;
  v_person_is_master_attribute_id integer;

  v_all_person_group_id integer;
  v_aster_group_id integer;
  v_un_group_id integer;
  v_mars_group_id integer;
  v_opa_group_id integer;
  v_master_group_id integer;
  v_player_group_id integer;

  v_default_login_id integer;
  v_menu_id integer;
  v_notifications_id integer;
  v_test_id integer;
  v_person_id integer;
  v_person_class_id integer;

  v_template_groups jsonb[];
begin
  insert into data.attributes(code, description, type, card_type, can_be_overridden)
  values('description', 'Текстовый блок с развёрнутым описанием объекта, string', 'normal', 'full', true)
  returning id into v_description_attribute_id;

  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden)
  values ('person_occupation', null, 'Должность', 'normal', null, null, false)
  returning id into v_person_occupation_attribute_id;

  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden)
  values ('person_state', null, 'Гражданство', 'normal', 'full', 'pallas_project.vd_person_state', false)
  returning id into v_person_state_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('system_money', 'Остаток средств на счёте', 'system', null, null, false)
  returning id into v_system_money_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('money', 'Остаток средств на счёте', 'normal', 'full', null, true)
  returning id into v_money_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('system_person_deposit_money', 'Остаток средств на накопительном счёте', 'system', null, null, false)
  returning id into v_system_person_deposit_money_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('person_deposit_money', 'Остаток средств на накопительном счёте', 'normal', 'full', null, true)
  returning id into v_person_deposit_money_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('system_person_coin', 'Остаток коинов', 'system', null, null, false)
  returning id into v_system_person_coin_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('person_coin', 'Остаток коинов', 'normal', 'full', null, true)
  returning id into v_person_coin_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('system_person_opa_rating', 'Рейтинг в СВП', 'system', null, null, false)
  returning id into v_system_person_opa_rating_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('person_opa_rating', 'Рейтинг в СВП', 'normal', 'full', null, true)
  returning id into v_person_opa_rating_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('system_person_un_rating', 'Рейтинг в ООН', 'system', null, null, false)
  returning id into v_system_person_un_rating_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('person_un_rating', 'Рейтинг в ООН', 'normal', 'full', null, true)
  returning id into v_person_un_rating_attribute_id;

  -- Создадим актора по умолчанию, который является первым тестом
  insert into data.objects(code) values('anonymous') returning id into v_test_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_title_attribute_id, jsonb '"Unknown"'),
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
                                      '{"code": "%s", "actions": ["%s", "%s", "%s"]}',
                                      'menu_group1',
                                      'login',
                                      'debatles',
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
  begin
    insert into data.objects(code) values('not_found') returning id into v_not_found_object_id;
    insert into data.params(code, value, description)
    values('not_found_object_id', to_jsonb(v_not_found_object_id), 'Идентификатор объекта, отображаемого в случае, если актору недоступен какой-то объект (ну или он реально не существует)');

    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_not_found_object_id, v_type_attribute_id, jsonb '"not_found"'),
    (v_not_found_object_id, v_is_visible_attribute_id, jsonb 'true'),
    (v_not_found_object_id, v_title_attribute_id, jsonb '"404"'),
    (v_not_found_object_id, v_subtitle_attribute_id, jsonb '"Not found"'),
    (v_not_found_object_id, v_description_attribute_id, jsonb '"Это не те дроиды, которых вы ищете."');
  end;

  insert into data.actions(code, function) values
  ('act_open_object', 'pallas_project.act_open_object'),
  ('login', 'pallas_project.act_login'),
  ('logout', 'pallas_project.act_logout'),
  ('go_back', 'pallas_project.act_go_back'),
  ('create_random_person', 'pallas_project.act_create_random_person');

  --Объект класса для персон
  insert into data.objects(code, type) values('person', 'class') returning id into v_person_class_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_class_id, v_type_attribute_id, jsonb '"person"'),
  (v_person_class_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_person_class_id, v_full_card_function_attribute_id, jsonb '"pallas_project.fcard_person"'),
  (v_person_class_id, v_mini_card_function_attribute_id, jsonb '"pallas_project.mcard_person"'),
  (v_person_class_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_menu"'),
  (v_person_class_id, v_template_attribute_id, jsonb_build_object('groups', array[format(
                                                      '{"code": "%s", "attributes": ["%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s"]}',
                                                      'person_group1',
                                                      'person_state',
                                                      'person_occupation',
                                                      'money',
                                                      'person_deposit_money',
                                                      'person_coin',
                                                      'person_opa_rating',
                                                      'person_un_rating',
                                                      'description')::jsonb]));

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text 'Добрый день!')
  );

  -- Группы персон
  insert into data.objects(code) values ('all_person') returning id into v_all_person_group_id;
  insert into data.objects(code) values ('aster') returning id into v_aster_group_id;
  insert into data.objects(code) values ('un') returning id into v_un_group_id;
  insert into data.objects(code) values ('mars') returning id into v_mars_group_id;
  insert into data.objects(code) values ('opa') returning id into v_opa_group_id;
  insert into data.objects(code) values ('master') returning id into v_master_group_id;
  insert into data.objects(code) values ('player') returning id into v_player_group_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_all_person_group_id, v_priority_attribute_id, jsonb '10'),
  (v_player_group_id, v_priority_attribute_id, jsonb '15'),
  (v_aster_group_id, v_priority_attribute_id, jsonb '20'),
  (v_un_group_id, v_priority_attribute_id, jsonb '30'),
  (v_mars_group_id, v_priority_attribute_id, jsonb '40'),
  (v_opa_group_id, v_priority_attribute_id, jsonb '50'),
  (v_master_group_id, v_priority_attribute_id, jsonb '190');
/*
  -- Данные персон
  insert into data.objects(code, class_id) values('person1', v_person_class_id) returning id into v_person_id;
    -- Логин
  insert into data.logins(code) values('p1') returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_person_id);
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_id, v_title_attribute_id, jsonb '"Джерри Адамс"'),
  (v_person_id, v_priority_attribute_id, jsonb '200'),
  (v_person_id, v_person_state_attribute_id, jsonb '"un"'),
  (v_person_id, v_person_occupation_attribute_id, jsonb '"Секретарь администрации"'),
  (v_person_id, v_system_money_attribute_id, jsonb '0'),
  (v_person_id, v_system_person_coin_attribute_id, jsonb '50'),
  (v_person_id, v_system_person_opa_rating_attribute_id, jsonb '1'),
  (v_person_id, v_system_person_un_rating_attribute_id, jsonb '150');

  insert into data.object_objects(parent_object_id, object_id) values
  (v_all_person_group_id, v_person_id),
  (v_un_group_id, v_person_id),
  (v_player_group_id, v_person_id);
*/
  insert into data.objects(code, class_id) values('person2', v_person_class_id) returning id into v_person_id;
    -- Логин
  insert into data.logins(code) values('m1') returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_person_id);
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_id, v_title_attribute_id, jsonb '"Саша"'),
  (v_person_id, v_person_occupation_attribute_id, jsonb '"Мастер"'),
  (v_person_id, v_priority_attribute_id, jsonb '200');

  insert into data.object_objects(parent_object_id, object_id) values
  (v_all_person_group_id, v_person_id),
  (v_master_group_id, v_person_id);

  insert into data.objects(code, class_id) values('person4', v_person_class_id) returning id into v_person_id;
    -- Логин
  insert into data.logins(code) values('m2') returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_person_id);
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_id, v_title_attribute_id, jsonb '"Пётр"'),
  (v_person_id, v_person_occupation_attribute_id, jsonb '"Мастер"'),
  (v_person_id, v_priority_attribute_id, jsonb '200');

  insert into data.object_objects(parent_object_id, object_id) values
  (v_all_person_group_id, v_person_id),
  (v_master_group_id, v_person_id);

  insert into data.objects(code, class_id) values('person5', v_person_class_id) returning id into v_person_id;
    -- Логин
  insert into data.logins(code) values('m3') returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_person_id);
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_id, v_title_attribute_id, jsonb '"Данил"'),
  (v_person_id, v_person_occupation_attribute_id, jsonb '"Мастер"'),
  (v_person_id, v_priority_attribute_id, jsonb '200');

  insert into data.object_objects(parent_object_id, object_id) values
  (v_all_person_group_id, v_person_id),
  (v_master_group_id, v_person_id);
/*
insert into data.objects(code, class_id) values('person3', v_person_class_id) returning id into v_person_id;
    -- Логин
  insert into data.logins(code) values('p3') returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_person_id);
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_id, v_title_attribute_id, jsonb '"Сьюзан Сидорова"'),
  (v_person_id, v_priority_attribute_id, jsonb '200'),
  (v_person_id, v_person_state_attribute_id, jsonb '"aster"'),
  (v_person_id, v_person_occupation_attribute_id, jsonb '"Шахтёр"'),
  (v_person_id, v_system_money_attribute_id, jsonb '65000'),
  (v_person_id, v_system_person_opa_rating_attribute_id, jsonb '5'),
  (v_person_id, v_system_person_un_rating_attribute_id, jsonb '0');

  insert into data.object_objects(parent_object_id, object_id) values
  (v_all_person_group_id, v_person_id),
  (v_opa_group_id, v_person_id),
  (v_player_group_id, v_person_id),
  (v_aster_group_id, v_person_id);
*/
  perform pallas_project.init_debatles();
end;
$$
language plpgsql;
