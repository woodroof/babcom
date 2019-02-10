-- drop function pallas_project.init_economics();

create or replace function pallas_project.init_economics()
returns void
volatile
as
$$
begin
  insert into data.params(code, value) values
  ('economic_cycle_number', jsonb '1');

  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('life_support_status', null, 'Описание на странице статуса', 'normal', null, 'pallas_project.vd_life_support_status', false),
  ('health_care_status', null, 'Описание на странице статуса', 'normal', null, 'pallas_project.vd_health_care_status', false),
  ('recreation_status', null, 'Описание на странице статуса', 'normal', null, 'pallas_project.vd_recreation_status', false),
  ('police_status', null, 'Описание на странице статуса', 'normal', null, 'pallas_project.vd_police_status', false),
  ('administrative_services_status', null, 'Описание на странице статуса', 'normal', null, 'pallas_project.vd_administrative_services_status', false),
  ('cycle', null, 'Текущий экономический цикл', 'normal', null, 'pallas_project.vd_cycle', false);

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
      {"code": "title", "value": "Статусы"}
    ]');
end;
$$
language plpgsql;
