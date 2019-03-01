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
  ('package_from', 'Откуда', 'Откуда посылка', 'normal', 'full', null, false),
  ('package_ship', 'Корабль', 'Корабль, на котором прибыла посылка', 'normal', 'full', null, false),
  ('package_what', 'Описание груза', 'Описание посылки', 'normal', 'full', null, false),
  ('package_receiver_status', 'Статус получателя', 'Статус получателя', 'normal', 'full', null, false),
  ('system_package_to', null, 'Адресат', 'system', null, null, false),
  ('system_package_receiver_code', null, 'Код для получения', 'system', null, null, false),
  ('package_receiver_code', 'Код для получения', 'Код для получения', 'normal', null, null, true),
  ('system_package_box_code', null, 'Код коробки', 'system', null, null, false),
  ('package_box_code', 'Код коробки', 'Код коробки', 'normal', null, null, true),
  ('package_to', 'Адресат', 'Адресат', 'system', null, null, true),
  ('package_weight', 'Вес, кг.', 'Вес посылки', 'normal', 'full', null, false),
  ('package_arrival_time', 'Дата прибытия', 'Дата прибытия', 'normal', null, null, false),
  ('package_status', 'Статус', 'Статус посылки', 'normal', null, 'pallas_project.vd_package_status', false),
  ('system_package_reactions', null, 'Список проверок, на которые положительно реагирует', 'system', null, null, false),
  ('package_reactions', null, 'Список проверок, на которые положительно реагирует', 'normal', null, null, true),
  ('system_package_ships_before_come', null, 'Количество кораблей до прибытия груза', 'system', null, null, false),
  ('system_package_id', null, 'Идентификатор посылки для проверок', 'system', null, null, false),
  ('system_customs_cheking', null, 'Признак, что таможня проверяет какой-то груз', 'system', null, null, false);

  -- Объект - страница для таможни
  perform data.create_object(
  'customs',
  jsonb '[
    {"code": "title", "value": "Таможня"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "is_visible", "value": true, "value_object_code": "customs_officer"},
    {"code": "content", "value": []},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "actions_function", "value": "pallas_project.actgenerator_customs"},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [{"code": "customs_group", "attributes": ["description"], "actions": ["customs_ship_arrival", "customs_future_packages"]}]
      }
    }
  ]');

  -- Списки посылок
  -- Класс
  perform data.create_class(
  'customs_package_list',
  jsonb '[
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "is_visible", "value": true, "value_object_code": "customs_officer"},
    {"code": "content", "value": []},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "independent_from_object_list_elements", "value": true},
    {"code": "actions_function", "value": "pallas_project.actgenerator_customs_package_list"},
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
  'customs_future_packages',
  jsonb '[
    {"code": "title", "value": "Будущие посылки"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "content", "value": []},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "independent_from_object_list_elements", "value": true},
    {"code": "actions_function", "value": "pallas_project.actgenerator_customs_future_packages"},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [{"code": "package_list_group1", "attributes": ["description"]},
                   {"code": "package_list_group2", "actions": ["customs_create_future_package"]}]
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
    {"code": "actions_function", "value": "pallas_project.actgenerator_customs_package"},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "subtitle": "package_status",
        "groups": []
      }
    },
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [
          {
            "code": "package_group1",
            "attributes": ["package_status","package_arrival_time", "package_from", "package_ship", "package_what", "package_weight"]
          },
          {
            "code": "package_group1",
            "attributes": ["package_receiver_code", "package_to"]
          },
          {
            "code": "package_group2",
            "actions": ["customs_package_check_spectrometer", "customs_package_check_radiation", "customs_package_chack_x_ray"]
          },
          {
            "code": "package_group3",
            "actions": ["customs_package_set_checked", "customs_package_set_arrested", "customs_package_receive"]
          }
        ]
      }
    }
  ]');


  insert into data.actions(code, function) values
  ('customs_package_list_go_back', 'pallas_project.act_customs_package_list_go_back'),
  ('customs_ship_arrival', 'pallas_project.act_customs_ship_arrival'),
  ('customs_create_future_package', 'pallas_project.act_customs_create_future_package'),
  ('customs_package_check','pallas_project.act_customs_package_check'),
  ('customs_package_set_checked','pallas_project.act_customs_package_set_checked'),
  ('customs_package_set_arrested', 'pallas_project.act_customs_package_set_arrested'),
  ('customs_package_receive', 'pallas_project.act_customs_package_receive');
end;
$$
language plpgsql;
