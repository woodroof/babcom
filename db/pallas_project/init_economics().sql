-- drop function pallas_project.init_economics();

create or replace function pallas_project.init_economics()
returns void
volatile
as
$$
begin
  insert into data.params(code, value) values
  ('economic_cycle_number', jsonb '1'),
  ('token_price', jsonb '1000'),
  ('life_support_status_prices', jsonb '[1, 2, 4]'),
  ('health_care_status_prices', jsonb '[1, 2, 4]'),
  ('recreation_status_prices', jsonb '[1, 2, 4]'),
  ('police_status_prices', jsonb '[1, 2, 4]'),
  ('administrative_services_status_prices', jsonb '[1, 2, 4]');

  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('life_support_status', null, 'Описание на странице статуса', 'normal', null, 'pallas_project.vd_life_support_status', false),
  ('health_care_status', null, 'Описание на странице статуса', 'normal', null, 'pallas_project.vd_health_care_status', false),
  ('recreation_status', null, 'Описание на странице статуса', 'normal', null, 'pallas_project.vd_recreation_status', false),
  ('police_status', null, 'Описание на странице статуса', 'normal', null, 'pallas_project.vd_police_status', false),
  ('administrative_services_status', null, 'Описание на странице статуса', 'normal', null, 'pallas_project.vd_administrative_services_status', false),
  ('life_support_next_status', null, 'Статус на странице покупки', 'normal', null, 'pallas_project.vd_status', false),
  ('health_care_next_status', null, 'Статус на странице покупки', 'normal', null, 'pallas_project.vd_status', false),
  ('recreation_next_status', null, 'Статус на странице покупки', 'normal', null, 'pallas_project.vd_status', false),
  ('police_next_status', null, 'Статус на странице покупки', 'normal', null, 'pallas_project.vd_status', false),
  ('administrative_services_next_status', null, 'Статус на странице покупки', 'normal', null, 'pallas_project.vd_status', false),
  ('cycle', null, 'Текущий экономический цикл', 'normal', null, 'pallas_project.vd_cycle', false);

  insert into data.actions(code, function) values
  ('buy_status', 'pallas_project.act_buy_status');

  perform data.create_class(
    'life_support_status_page',
    jsonb '[
      {"code": "title", "value": "Жизнеобеспечение"},
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {
        "code": "mini_card_template",
        "value": {
          "title": "title",
          "groups": [{"code": "status_group", "attributes": ["life_support_status"]}]
        }
      },
      {
        "code": "template",
        "value": {
          "title": "title",
          "subtitle": "cycle",
          "groups": [{"code": "status_group", "attributes": ["life_support_status"]}]
        }
      }
    ]');
  perform data.create_class(
    'health_care_status_page',
    jsonb '[
      {"code": "title", "value": "Медицина"},
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {
        "code": "mini_card_template",
        "value": {
          "title": "title",
          "groups": [{"code": "status_group", "attributes": ["health_care_status"]}]
        }
      },
      {
        "code": "template",
        "value": {
          "title": "title",
          "subtitle": "cycle",
          "groups": [{"code": "status_group", "attributes": ["health_care_status"]}]
        }
      }
    ]');
  perform data.create_class(
    'recreation_status_page',
    jsonb '[
      {"code": "title", "value": "Развлечения"},
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {
        "code": "mini_card_template",
        "value": {
          "title": "title",
          "groups": [{"code": "status_group", "attributes": ["recreation_status"]}]
        }
      },
      {
        "code": "template",
        "value": {
          "title": "title",
          "subtitle": "cycle",
          "groups": [{"code": "status_group", "attributes": ["recreation_status"]}]
        }
      }
    ]');
  perform data.create_class(
    'police_status_page',
    jsonb '[
      {"code": "title", "value": "Полиция"},
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {
        "code": "mini_card_template",
        "value": {
          "title": "title",
          "groups": [{"code": "status_group", "attributes": ["police_status"]}]
        }
      },
      {
        "code": "template",
        "value": {
          "title": "title",
          "subtitle": "cycle",
          "groups": [{"code": "status_group", "attributes": ["police_status"]}]
        }
      }
    ]');
  perform data.create_class(
    'administrative_services_status_page',
    jsonb '[
      {"code": "title", "value": "Административное обслуживание"},
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {
        "code": "mini_card_template",
        "value": {
          "title": "title",
          "groups": [{"code": "status_group", "attributes": ["administrative_services_status"]}]
        }
      },
      {
        "code": "template",
        "value": {
          "title": "title",
          "subtitle": "cycle",
          "groups": [{"code": "status_group", "attributes": ["administrative_services_status"]}]
        }
      }
    ]');

  perform data.create_class(
    'statuses',
    jsonb '[
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {"code": "type", "value": "statuses"},
      {"code": "title", "value": "Статусы"}
    ]');

  perform data.create_class(
    'next_statuses',
    jsonb '[
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {"code": "title", "value": "Покупка статусов"},
      {"code": "type", "value": "status_shop"},
      {"code": "actions_function", "value": "pallas_project.actgenerator_next_statuses"},
      {
        "code": "template",
        "value": {
          "title": "title",
          "subtitle": "cycle",
          "groups": [
            {"code": "left", "attributes": ["money", "person_coin"]},
            {"name": "Жизнеобеспечение", "code": "life_support", "attributes": ["life_support_next_status"], "actions": ["life_support_silver", "life_support_gold"]},
            {"name": "Медицина", "code": "health_care", "attributes": ["health_care_next_status"], "actions": ["health_care_bronze", "health_care_silver", "health_care_gold"]},
            {"name": "Развлечения", "code": "recreation", "attributes": ["recreation_next_status"], "actions": ["recreation_bronze", "recreation_silver", "recreation_gold"]},
            {"name": "Полиция", "code": "police", "attributes": ["police_next_status"], "actions": ["police_bronze", "police_silver", "police_gold"]},
            {"name": "Административное обслуживание", "code": "administrative_services", "attributes": ["administrative_services_next_status"], "actions": ["administrative_services_bronze", "administrative_services_silver", "administrative_services_gold"]}
          ]
        }
      }
    ]');
end;
$$
language plpgsql;
