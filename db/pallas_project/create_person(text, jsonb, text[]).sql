-- drop function pallas_project.create_person(text, jsonb, text[]);

create or replace function pallas_project.create_person(in_login_code text, in_attributes jsonb, in_groups text[])
returns void
volatile
as
$$
-- Не для использования на игре, т.к. обновляет атрибуты напрямую, без уведомлений и блокировок!
declare
  v_person_id integer := data.create_object(null, in_attributes, 'person', in_groups);
  v_person_code text := data.get_object_code(v_person_id);
  v_login_id integer;
  v_master_group_id integer := data.get_object_id('master');
  v_economy_type jsonb := data.get_attribute_value(v_person_id, 'system_person_economy_type');
  v_attributes jsonb;
begin
  insert into data.logins(code) values(in_login_code) returning id into v_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_login_id, v_person_id);

  if v_economy_type is not null then
    declare
      v_cycle integer;
      v_money jsonb;
      v_deposit_money jsonb;
      v_coin jsonb;
    begin
      perform data.set_attribute_value(v_person_id, 'person_economy_type', v_economy_type, v_master_group_id);

      v_cycle := data.get_integer_param('economic_cycle_number');

      -- Переложим суммы остатков
      if v_economy_type != jsonb '"un"' and v_economy_type != jsonb '"fixed"' then
        v_money := data.get_attribute_value(v_person_id, 'system_money');
        perform json.get_integer(v_money);

        perform data.set_attribute_value(v_person_id, 'money', v_money, v_person_id);
        perform data.set_attribute_value(v_person_id, 'money', v_money, v_master_group_id);
      end if;

      if v_economy_type = jsonb '"asters"' then
        v_deposit_money := data.get_attribute_value(v_person_id, 'system_person_deposit_money');
        perform json.get_integer(v_deposit_money);

        perform data.set_attribute_value(v_person_id, 'person_deposit_money', v_deposit_money, v_person_id);
        perform data.set_attribute_value(v_person_id, 'person_deposit_money', v_deposit_money, v_master_group_id);
      end if;

      if v_economy_type = jsonb '"un"' then
        v_coin := data.get_attribute_value(v_person_id, 'system_person_coin');
        perform json.get_integer(v_coin);

        perform data.set_attribute_value(v_person_id, 'person_coin', v_coin, v_person_id);
        perform data.set_attribute_value(v_person_id, 'person_coin', v_coin, v_master_group_id);
      end if;

      -- Заполним будущие статусы
      if v_economy_type != jsonb '"fixed"' then
        perform data.set_attribute_value(v_person_id, 'system_person_next_life_support_status', jsonb '1');
        perform data.set_attribute_value(v_person_id, 'system_person_next_health_care_status', jsonb '0');
        perform data.set_attribute_value(v_person_id, 'system_person_next_recreation_status', jsonb '0');
        perform data.set_attribute_value(v_person_id, 'system_person_next_police_status', jsonb '0');
        perform data.set_attribute_value(v_person_id, 'system_person_next_administrative_services_status', jsonb '0');
      end if;

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

      if v_economy_type != jsonb '"fixed"' then
        -- Создадим страницу для покупки статусов
        v_attributes :=
          format(
            '[
              {"code": "cycle", "value": %s},
              {"code": "is_visible", "value": true, "value_object_id": %s},
              {"code": "life_support_next_status", "value": 1},
              {"code": "health_care_next_status", "value": 0},
              {"code": "recreation_next_status", "value": 0},
              {"code": "police_next_status", "value": 0},
              {"code": "administrative_services_next_status", "value": 0}
            ]',
            v_cycle,
            v_person_id)::jsonb;

        if v_economy_type = jsonb '"un"' then
          v_attributes := v_attributes || data.attribute_change2jsonb('person_coin', data.get_attribute_value(v_person_id, 'system_person_coin'));
        else
          v_attributes := v_attributes || data.attribute_change2jsonb('money', data.get_attribute_value(v_person_id, 'system_money'));
        end if;

        perform data.create_object(
          v_person_code || '_next_statuses',
          v_attributes,
          'next_statuses');

        if v_economy_type != jsonb '"un"' and v_economy_type != jsonb '"fixed"' then
          -- Создадим страницу с историей транзакций
          perform data.create_object(
            v_person_code || '_transactions',
            format(
              '[
                {"code": "is_visible", "value": true, "value_object_id": %s},
                {"code": "content", "value": []}
              ]',
              v_person_id)::jsonb,
            'transactions');
        end if;
      end if;
    end;
  end if;

  -- Обновим район, если есть
  declare
    v_district text := json.get_string_opt(data.get_attribute_value(v_person_id, 'person_district'), null);
    v_district_id integer;
    v_is_person boolean;
    v_content jsonb;
  begin
    if v_district is not null then
      v_district_id := data.get_object_id(v_district);
      v_is_person := pp_utils.is_in_group(v_person_id, 'player');

      if v_is_person then
        select jsonb_agg(o.code order by data.get_attribute_value(o.id, data.get_attribute_id('title'), o.id))
        into v_content
        from jsonb_array_elements(data.get_raw_attribute_value(v_district_id, 'content') || to_jsonb(v_person_code)) arr
        join data.objects o on
          o.code = json.get_string(arr.value);

        perform data.set_attribute_value(v_district_id, 'content', v_content, null);
      end if;

      -- Для мастера видны все персонажи
      select jsonb_agg(o.code order by data.get_attribute_value(o.id, data.get_attribute_id('title'), o.id))
      into v_content
      from jsonb_array_elements(data.get_raw_attribute_value(v_district_id, 'content', v_master_group_id) || to_jsonb(v_person_code)) arr
      join data.objects o on
        o.code = json.get_string(arr.value);

      perform data.set_attribute_value(v_district_id, 'content', v_content, v_master_group_id);
    end if;
  end;
end;
$$
language plpgsql;
