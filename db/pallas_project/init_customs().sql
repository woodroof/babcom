-- drop function pallas_project.init_customs();

create or replace function pallas_project.init_customs()
returns void
volatile
as
$$
declare

begin
  -- Атрибуты 
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('package_from', 'Откуда', 'Откуда посылка', 'normal', null, null, false),
  ('package_what', 'Описание груза', 'Описание посылки', 'normal', null, null, false),
  ('package_receiver_status', 'Статус получателя', 'Статус получателя', 'normal', null, 'pallas_project.vd_status', false),
  ('system_package_to', null, 'Адресат', 'system', null, null, false),
  ('package_to', 'Адресат', 'Адресат', 'normal', null, 'pallas_project.vd_link', true),
  ('system_package_receiver_code', null, 'Код для получения', 'system', null, null, false),
  ('package_receiver_code', 'Код для получения', 'Код для получения', 'normal', null, null, true),
  ('system_package_box_code', null, 'Код коробки', 'system', null, null, false),
  ('package_box_code', 'Код коробки', 'Код коробки', 'normal', null, null, true),
  ('package_weight', 'Вес, кг.', 'Вес посылки', 'normal', null, null, false),
  ('package_arrival_time', 'Дата прибытия', 'Дата прибытия', 'normal', null, null, false),
  ('package_status', 'Статус', 'Статус посылки', 'normal', null, 'pallas_project.vd_package_status', false),
  ('system_package_reactions', null, 'Список проверок, на которые положительно реагирует', 'system', null, null, false),
  ('package_reactions', null, 'Список проверок, на которые положительно реагирует', 'normal', null, 'pallas_project.vd_package_reactions', true),
  ('package_cheked_reactions', null, 'Список проведённых проверок с результатами', 'normal', null, 'pallas_project.vd_package_checked_reactions', false),
  ('package_ships_before_come', 'Количество кораблей до прибытия груза', 'Количество кораблей до прибытия груза', 'normal', null, null, true),
  ('system_customs_checking', null, 'Признак, что таможня проверяет какой-то груз', 'system', null, null, false);

  insert into data.params(code, value, description) values
  ('customs_goods', 
  jsonb '{
    "тампоны гигиенические": [],
    "мяч": [],
    "одежда синтетическая": [],
    "кабель электрический": ["metal"],
    "набор мебели IKEA": ["metal"],
    "кофеварка": ["metal"],
    "аптечка \"Здоровый астер\"": ["metal"],
    "лампы осветительные": ["metal"],
    "коммуникатор NOD300": ["metal"],
    "шляпа": [],
    "кресло офисное": ["metal"],
    "горшок цветочный": [],
    "косметика": [],
    "бижутерия": ["metal"],
    "подушки": [],
    "сухари": [],
    "консервированное мясо": [],
    "соевый соус": [],
    "клубничный джем": [],
    "вата": [],
    "молоко сухое": [],
    "кофе": [],
    "чай": [],
    "сахар": [],
    "соль": [],
    "посуда": [],
    "датчики освещения": ["metal"],
    "перья птичьи": [],
    "уксус": [],
    "картина": [],
    "модель корабля": [],
    "тапочки": [],
    "туфли": [],
    "перчатки": [],
    "гуталин": [],
    "крекеры": [],
    "клетка": ["metal"],
    "галстук": [],
    "рюкзак": ["metal"],
    "мыло": [],
    "карамель": [],
    "краска": [],
    "кот Шрёдингера (муляж)": [],
    "гантели": ["metal"],
    "крем для рук": [],
    "шнурки": [],
    "трубы пластиковые": [],
    "набор LEGO \"Станция Паллада\"": []
  }', 'Товары для таможни'),
  ('customs_from', to_jsonb(string_to_array('Церера Паллада Юнона Веста Флора Ида Матильда Эрос Гаспра Икарус Географ Аполлон ' ||
  'Хирон Тоутатис Касталия Земля Луна Марс Фобос Деймос Ио Европа Ганимед Каллисто Сатурн Мимас Энцелад Тефия Диона Рея Титан '||
  'Елена Япет Уран Миранда Ариэль Умбриэль Титания Оберон Нептун Тритон Протей Нереид Наяда Таласса Деспина Ларисса Галатея', ' ')), 'Варианты откуда товар');

  -- Объект - страница для таможни
  perform data.create_object(
  'customs',
  jsonb '[
    {"code": "title", "value": "Таможня"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "is_visible", "value": true, "value_object_code": "customs_officer"},
    {"code": "actions_function", "value": "pallas_project.actgenerator_customs"},
    {"code": "content", "value": ["customs_new", "customs_checked", "customs_arrested", "customs_received"]},
    {"code": "content", "value": ["customs_future", "customs_new", "customs_checked", "customs_arrested", "customs_received"], "value_object_code": "master"},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "independent_from_object_list_elements", "value": true},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [{"code": "package_list_group1", "attributes": ["description"], "actions": ["customs_find_by_number", "customs_find_by_status_or_from"]}]
      }
    }
  ]');

  perform data.create_object(
  'customs_new',
  jsonb '[
    {"code": "title", "value": "Ждут проверки"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "is_visible", "value": true, "value_object_code": "customs_officer"},
    {"code": "content", "value": []},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "list_element_function", "value": "pallas_project.lef_do_nothing"},
    {"code": "list_actions_function", "value": "pallas_project.actgenerator_customs_content"},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": []
      }
    }
  ]');
  perform data.create_object(
  'customs_checked',
  jsonb '[
    {"code": "title", "value": "Проверены"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "is_visible", "value": true, "value_object_code": "customs_officer"},
    {"code": "content", "value": []},
    {"code": "independent_from_object_list_elements", "value": true},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "list_element_function", "value": "pallas_project.lef_do_nothing"},
    {"code": "list_actions_function", "value": "pallas_project.actgenerator_customs_content"},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": []
      }
    }
  ]');
  perform data.create_object(
  'customs_arrested',
  jsonb '[
    {"code": "title", "value": "Задержаны или арестованы"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "is_visible", "value": true, "value_object_code": "customs_officer"},
    {"code": "content", "value": []},
    {"code": "independent_from_object_list_elements", "value": true},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "list_element_function", "value": "pallas_project.lef_do_nothing"},
    {"code": "list_actions_function", "value": "pallas_project.actgenerator_customs_content"},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": []
      }
    }
  ]');

  perform data.create_object(
  'customs_received',
  jsonb '[
    {"code": "title", "value": "Выданы"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "is_visible", "value": true, "value_object_code": "customs_officer"},
    {"code": "content", "value": []},
    {"code": "independent_from_object_list_elements", "value": true},
    {"code": "list_element_function", "value": "pallas_project.lef_do_nothing"},
    {"code": "independent_from_actor_list_elements", "value": true},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": []
      }
    }
  ]');

  -- Списки посылок
  -- Класс
  perform data.create_class(
  'customs_package_list',
  jsonb '[
    {"code": "title", "value": "Таможня"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "is_visible", "value": true, "value_object_code": "customs_officer"},
    {"code": "content", "value": []},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "list_element_function", "value": "pallas_project.lef_do_nothing"},
    {"code": "list_actions_function", "value": "pallas_project.actgenerator_customs_content"},
    {"code": "temporary_object", "value": true},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [{"code": "package_list_group1", "attributes": ["description"], "actions": ["customs_package_list_go_back"]}]
      }
    }
  ]');

  -- Мастерский список будущих посылок
  perform data.create_object(
  'customs_future',
  jsonb '[
    {"code": "title", "value": "Будущие посылки"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "content", "value": []},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "independent_from_object_list_elements", "value": true},
    {"code": "actions_function", "value": "pallas_project.actgenerator_customs_future"},
    {"code": "list_actions_function", "value": "pallas_project.actgenerator_customs_future_content"},
    {"code": "list_element_function", "value": "pallas_project.lef_do_nothing"},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [{"code": "package_list_group1", "attributes": ["description"]},
                   {"code": "package_list_group2", "actions": ["customs_create_future_package", "customs_ship_arrival"]}]
      }
    }
  ]');

  -- Объект-класс для посылки
  perform data.create_class(
  'package',
  jsonb '[
    {"code": "type", "value": "package"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "is_visible", "value": true, "value_object_code": "customs_officer"},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "subtitle": "package_status",
        "groups": [
          {
            "code": "package_group1",
            "attributes": ["package_arrival_time", "package_from", "package_what", "package_weight", "package_receiver_status"]
          },
          {
            "code": "package_group2",
            "attributes": ["package_receiver_code", "package_to", "package_ships_before_come", "package_reactions", "package_box_code", "package_cheked_reactions"],
            "actions": ["customs_package_check_spectrometer", "customs_package_check_radiation", "customs_package_chack_x_ray"]
          },
          {
            "code": "package_group4",
            "actions": ["customs_package_set_checked", "customs_package_set_frozen", "customs_package_set_arrested", "customs_package_set_new", "customs_package_receive", "customs_package_delete"]
          }
        ]
      }
    },
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "package_status",
        "groups": [
          {
            "code": "package_group1",
            "attributes": ["package_arrival_time", "package_from", "package_what", "package_weight", "package_receiver_status"]
          },
          {
            "code": "package_group2",
            "attributes": ["package_receiver_code", "package_to", "package_ships_before_come", "package_reactions", "package_box_code", "package_cheked_reactions"]
          }
        ]
      }
    }
  ]');

  perform data.create_object(
  'check_life',
  jsonb '[
    {"code": "title", "value": "Запрещённые вещества и формы жизни"},
    {"code": "is_visible", "value": true},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "groups": []
      }
    }
  ]');
  perform data.create_object(
  'check_radiation',
  jsonb '[
    {"code": "title", "value": "Радиация"},
    {"code": "is_visible", "value": true},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "groups": []
      }
    }
  ]');
  perform data.create_object(
  'check_metal',
  jsonb '[
    {"code": "title", "value": "Металл"},
    {"code": "is_visible", "value": true},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "groups": []
      }
    }
  ]');

  -- Объект-класс для временных списков персон
  perform data.create_class(
  'customs_temp_future',
  jsonb '[
    {"code": "title", "value": "Добавить посылку"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "actions_function", "value": "pallas_project.actgenerator_customs_temp_future"},
    {"code": "list_element_function", "value": "pallas_project.lef_customs_temp_future"},
    {"code": "temporary_object", "value": true},
    {"code": "independent_from_actor_list_elements", "value": true},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [
          {
            "code": "group1",
            "actions": ["customs_future_back"]
          },
          {
            "code": "group2",
            "attributes": ["package_to", "package_reactions"],
            "actions": ["customs_temp_future_create"]
          }
        ]
      }
    }
  ]');

  insert into data.actions(code, function) values
  ('customs_package_list_go_back', 'pallas_project.act_customs_package_list_go_back'),
  ('customs_create_future_package', 'pallas_project.act_customs_create_future_package'),
  ('customs_package_check','pallas_project.act_customs_package_check'),
  ('customs_package_set_status','pallas_project.act_customs_package_set_status'),
  ('customs_package_receive', 'pallas_project.act_customs_package_receive'),
  ('customs_temp_future_create', 'pallas_project.act_customs_temp_future_create'),
  ('customs_find_by_number', 'pallas_project.act_customs_find_by_number'),
  ('customs_find_by_status_or_from', 'pallas_project.act_customs_find_by_status_or_from'),
  ('customs_ship_arrival', 'pallas_project.act_customs_ship_arrival'),
  ('customs_package_delete', 'pallas_project.act_customs_package_delete');
end;
$$
language plpgsql;
