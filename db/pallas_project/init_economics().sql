-- drop function pallas_project.init_economics();

create or replace function pallas_project.init_economics()
returns void
volatile
as
$$
declare
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_all_person_group_id integer := data.get_object_id('all_person');
begin
  insert into data.params(code, value) values
  ('economic_cycle_number', jsonb '1');

  perform pallas_project.create_class(
    'status_page',
    jsonb '{
      "full_card_function": "pallas_project.fcard_status_page",
      "mini_card_function": "pallas_project.mcard_status_page",
      "mini_card_template": {
        "title": "title",
        "groups": [{"code": "status_group", "attributes": ["mini_description"]}]
      },
      "template": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [{"code": "status_group", "attributes": ["description"]}]
      }
    }');

  perform pallas_project.create_object(
    'life_support_status_page',
    'status_page',
    jsonb '{
      "title": "Жизнеобеспечение"
    }',
    null);
  perform pallas_project.create_object(
    'health_care_status_page',
    'status_page',
    jsonb '{
      "title": "Медицина"
    }',
    null);
  perform pallas_project.create_object(
    'recreation_status_page',
    'status_page',
    jsonb '{
      "title": "Развлечения"
    }',
    null);
  perform pallas_project.create_object(
    'police_status_page',
    'status_page',
    jsonb '{
      "title": "Полиция"
    }',
    null);
  perform pallas_project.create_object(
    'administrative_services_status_page',
    'status_page',
    jsonb '{
      "title": "Административное обслуживание"
    }',
    null);

  perform pallas_project.create_object(
    'statuses',
    null,
    jsonb '{
      "is_visible": true,
      "title": "Статусы",
      "full_card_function": "pallas_project.fcard_statuses",
      "content": [
        "life_support_status_page",
        "health_care_status_page",
        "recreation_status_page",
        "police_status_page",
        "administrative_services_status_page"
      ]
    }',
    null);

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (data.get_object_id('statuses'), v_is_visible_attribute_id, jsonb 'true', v_all_person_group_id),
  (data.get_object_id('life_support_status_page'), v_is_visible_attribute_id, jsonb 'true', v_all_person_group_id),
  (data.get_object_id('health_care_status_page'), v_is_visible_attribute_id, jsonb 'true', v_all_person_group_id),
  (data.get_object_id('recreation_status_page'), v_is_visible_attribute_id, jsonb 'true', v_all_person_group_id),
  (data.get_object_id('police_status_page'), v_is_visible_attribute_id, jsonb 'true', v_all_person_group_id),
  (data.get_object_id('administrative_services_status_page'), v_is_visible_attribute_id, jsonb 'true', v_all_person_group_id);
end;
$$
language plpgsql;
