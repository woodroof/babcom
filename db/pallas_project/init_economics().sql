-- drop function pallas_project.init_economics();

create or replace function pallas_project.init_economics()
returns void
volatile
as
$$
begin
  insert into data.params(code, value) values
  ('economic_cycle_number', jsonb '1');

  perform data.create_class(
    'status_page',
    jsonb '[
      {"code": "full_card_function", "value": "pallas_project.fcard_status_page"},
      {"code": "mini_card_function", "value": "pallas_project.mcard_status_page"},
      {"code": "is_visible", "value": true, "value_object_code": "all_person"},
      {
        "code": "mini_card_template",
        "value": {
          "title": "title",
          "groups": [{"code": "status_group", "attributes": ["mini_description"]}]
        }
      },
      {
        "code": "template",
        "value": {
          "title": "title",
          "subtitle": "subtitle",
          "groups": [{"code": "status_group", "attributes": ["description"]}]
        }
      }
    ]');

  perform data.create_object(
    'life_support_status_page',
    jsonb '{"title": "Жизнеобеспечение"}',
    'status_page');
  perform data.create_object(
    'health_care_status_page',
    jsonb '{"title": "Медицина"}',
    'status_page');
  perform data.create_object(
    'recreation_status_page',
    jsonb '{"title": "Развлечения"}',
    'status_page');
  perform data.create_object(
    'police_status_page',
    jsonb '{"title": "Полиция"}',
    'status_page');
  perform data.create_object(
    'administrative_services_status_page',
    jsonb '{"title": "Административное обслуживание"}',
    'status_page');

  perform data.create_object(
    'statuses',
    jsonb '[
      {"code": "is_visible", "value": true, "value_object_code": "all_person"},
      {"code": "title", "value": "Статусы"},
      {"code": "full_card_function", "value": "pallas_project.fcard_statuses"},
      {
        "code": "content",
        "value": [
          "life_support_status_page",
          "health_care_status_page",
          "recreation_status_page",
          "police_status_page",
          "administrative_services_status_page"
        ]
      }
    ]');
end;
$$
language plpgsql;
