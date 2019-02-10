-- drop function pallas_project.create_person(text, jsonb, text[]);

create or replace function pallas_project.create_person(in_login_code text, in_attributes jsonb, in_groups text[])
returns void
volatile
as
$$
declare
  v_person_id integer := data.create_object(null, in_attributes, 'person', in_groups);
  v_person_code text := data.get_object_code(v_person_id);
  v_login_id integer;
  v_master_group_id integer := data.get_object_id('master');
  v_economy_type jsonb := data.get_attribute_value(v_person_id, 'system_person_economy_type');
  v_cycle integer;
begin
  insert into data.logins(code) values(in_login_code) returning id into v_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_login_id, v_person_id);

  if v_economy_type is not null then
    perform data.set_attribute_value(v_person_id, data.get_attribute_id('person_economy_type'), v_economy_type, v_master_group_id);

    v_cycle := data.get_integer_param('economic_cycle_number');

    -- Создадим страницу для статусов
    perform data.create_object(
      v_person_code || '_statuses',
      format(
        '[
          {"code": "cycle", "value": %s},
          {"code": "is_visible", "value": true, "value_object_id": %s},
          {
            "code": "content",
            "value": [
              "%s_life_support_status_page",
              "%s_health_care_status_page",
              "%s_recreation_status_page",
              "%s_police_status_page",
              "%s_administrative_services_status_page"
            ]
          }
        ]',
        v_cycle,
        v_person_id,
        v_person_code,
        v_person_code,
        v_person_code,
        v_person_code,
        v_person_code)::jsonb,
      'statuses');

    -- И страницы текущих статусов
    perform data.create_object(
      v_person_code || '_life_support_status_page',
      format(
        '[
          {"code": "cycle", "value": %s},
          {"code": "is_visible", "value": true, "value_object_id": %s},
          {"code": "life_support_status", "value": %s}
        ]',
        v_cycle,
        v_person_id,
        json.get_integer(data.get_attribute_value(v_person_id, 'system_person_life_support_status')))::jsonb,
      'life_support_status_page');
    perform data.create_object(
      v_person_code || '_health_care_status_page',
      format(
        '[
          {"code": "cycle", "value": %s},
          {"code": "is_visible", "value": true, "value_object_id": %s},
          {"code": "health_care_status", "value": %s}
        ]',
        v_cycle,
        v_person_id,
        json.get_integer(data.get_attribute_value(v_person_id, 'system_person_health_care_status')))::jsonb,
      'health_care_status_page');
    perform data.create_object(
      v_person_code || '_recreation_status_page',
      format(
        '[
          {"code": "cycle", "value": %s},
          {"code": "is_visible", "value": true, "value_object_id": %s},
          {"code": "recreation_status", "value": %s}
        ]',
        v_cycle,
        v_person_id,
        json.get_integer(data.get_attribute_value(v_person_id, 'system_person_recreation_status')))::jsonb,
      'recreation_status_page');
    perform data.create_object(
      v_person_code || '_police_status_page',
      format(
        '[
          {"code": "cycle", "value": %s},
          {"code": "is_visible", "value": true, "value_object_id": %s},
          {"code": "police_status", "value": %s}
        ]',
        v_cycle,
        v_person_id,
        json.get_integer(data.get_attribute_value(v_person_id, 'system_person_police_status')))::jsonb,
      'police_status_page');
    perform data.create_object(
      v_person_code || '_administrative_services_status_page',
      format(
        '[
          {"code": "cycle", "value": %s},
          {"code": "is_visible", "value": true, "value_object_id": %s},
          {"code": "administrative_services_status", "value": %s}
        ]',
        v_cycle,
        v_person_id,
        json.get_integer(data.get_attribute_value(v_person_id, 'system_person_administrative_services_status')))::jsonb,
      'administrative_services_status_page');
  end if;
end;
$$
language plpgsql;
