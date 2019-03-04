-- drop function pallas_project.create_person(text, text, jsonb, text[]);

create or replace function pallas_project.create_person(in_person_code text, in_login_code text, in_attributes jsonb, in_groups text[])
returns integer
volatile
as
$$
-- Не для использования на игре, т.к. обновляет атрибуты напрямую, без уведомлений и блокировок!
declare
  v_person_id integer := data.create_object(in_person_code, in_attributes, 'person', in_groups);
  v_person_code text := data.get_object_code(v_person_id);
  v_login_id integer;
  v_master_group_id integer := data.get_object_id('master');
  v_economy_type jsonb := data.get_attribute_value(v_person_id, 'system_person_economy_type');
  v_important_chat_id integer;
  v_attributes jsonb;
  v_is_master boolean := pp_utils.is_in_group(v_person_id, 'master');
  v_master_chats_id integer;
  v_master_chat_id integer := data.get_object_id('master_chat');
  v_master_person_id integer;
begin
  if in_login_code is not null then
    insert into data.logins(code) values(in_login_code) returning id into v_login_id;
    insert into data.login_actors(login_id, actor_id, is_main) values(v_login_id, v_person_id, true);
  end if;

  perform data.set_attribute_value(v_person_id, 'system_person_notification_count', jsonb '0');

  if v_economy_type is not null then
    declare
      v_cycle integer;
      v_money jsonb;
      v_deposit_money jsonb;
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
        declare
          v_coin integer := pallas_project.un_rating_to_coins(json.get_integer(data.get_attribute_value(v_person_id, 'person_un_rating')));
          v_life_support_prices integer[] := data.get_integer_array_param('life_support_status_prices');
          v_life_support_price integer := v_life_support_prices[1];
        begin
          v_coin := v_coin - v_life_support_price;
          perform data.set_attribute_value(v_person_id, 'system_person_coin', to_jsonb(v_coin));
          perform data.set_attribute_value(v_person_id, 'person_coin', to_jsonb(v_coin), v_person_id);
          perform data.set_attribute_value(v_person_id, 'person_coin', to_jsonb(v_coin), v_master_group_id);
        end;
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
              {"code": "status_shop_cycle", "value": %s},
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

        -- Создадим список контактов
        perform data.create_object(
          v_person_code || '_contracts',
          format(
            '[
              {"code": "title", "value": "Контракты"},
              {"code": "is_visible", "value": true, "value_object_id": %s},
              {"code": "content", "value": []}
            ]',
            v_person_id)::jsonb,
          'contract_list');
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
        select jsonb_agg(o.code order by data.get_attribute_value(o.id, data.get_attribute_id('title')))
        into v_content
        from jsonb_array_elements(data.get_raw_attribute_value(v_district_id, 'content') || to_jsonb(v_person_code)) arr
        join data.objects o on
          o.code = json.get_string(arr.value);

        perform data.set_attribute_value(v_district_id, 'content', v_content, null);
      end if;

      -- Для мастера видны все персонажи
      select jsonb_agg(o.code order by data.get_attribute_value(o.id, data.get_attribute_id('title')))
      into v_content
      from jsonb_array_elements(data.get_raw_attribute_value(v_district_id, 'content', v_master_group_id) || to_jsonb(v_person_code)) arr
      join data.objects o on
        o.code = json.get_string(arr.value);

      perform data.set_attribute_value(v_district_id, 'content', v_content, v_master_group_id);
    end if;
  end;

  -- Создадим "Мои организации"
  perform data.create_object(
    v_person_code || '_my_organizations',
    format(
      '[
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "content", "value": []}
      ]',
      v_person_id)::jsonb,
    'my_organizations');

  -- Уведомления
  perform data.create_object(
    v_person_code || '_notifications',
    format(
      '[
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "content", "value": []}
      ]',
      v_person_id)::jsonb,
    'notification_list');

 -- Создадим "Состояние здоровья"
  perform data.create_object(
    v_person_code || '_med_health',
    format(
      '[
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "med_health", "value": {}}
      ]',
      v_person_id)::jsonb,
    'med_health');

  -- Создадим "Мастерские чаты"
  v_master_chats_id := data.create_object(
    v_person_code || '_master_chats',
    format('[
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "title", "value": "Общение с мастерами"}
      ]',
      v_person_id)::jsonb,
      'chats');

   -- Создадим "Чаты"
  perform data.create_object(
    v_person_code || '_chats',
    format('[
        {"code": "is_visible", "value": true, "value_object_id": %s}
      ]',
      v_person_id)::jsonb,
      'chats');

  -- чат для важных уведомлений
  v_important_chat_id := pallas_project.create_chat(
    v_person_code || '_important_chat',
    jsonb_build_object(
      'content', jsonb '[]',
      'title', 'Важные уведомления',
      'system_chat_is_renamed', true,
      'system_chat_can_invite', false,
      'system_chat_can_leave', false,
      'system_chat_can_mute', false,
      'system_chat_can_rename', false,
      'system_chat_cant_write', true,
      'system_chat_cant_see_members', true
  ));
  perform data.add_object_to_object(v_person_id, v_important_chat_id);

  -- Добавление всех мастеров в мастерский чат и создание мастерского чата для каждого персонажа
  if v_is_master then
    perform data.add_object_to_object(v_person_id, v_master_chat_id);
    perform pp_utils.list_prepend_and_notify(v_master_chats_id, v_master_chat_id, null);
  else
    v_master_chat_id := pallas_project.create_chat(
      null,
      jsonb_build_object(
        'content', jsonb '[]',
        'title', 'Мастерский для ' || json.get_string(data.get_attribute_value(v_person_id, 'title')),
        'system_chat_is_renamed', true,
        'system_chat_can_invite', false,
        'system_chat_can_leave', false,
        'system_chat_can_mute', false,
        'system_chat_can_rename', false,
        'system_chat_parent_list', 'master_chats'
      ));
    perform data.add_object_to_object(v_person_id, v_master_chat_id);
    for v_master_person_id in (select * from unnest(pallas_project.get_group_members('master')))
    loop
      perform data.add_object_to_object(v_master_person_id, v_master_chat_id);
      perform pp_utils.list_prepend_and_notify(data.get_object_id(data.get_object_code(v_master_person_id) ||'_master_chats'), v_master_chat_id, null);
    end loop;
    perform pallas_project.change_chat_person_list_on_person(v_master_chat_id, null, true);
    perform pp_utils.list_prepend_and_notify(v_master_chats_id, v_master_chat_id, null);
  end if;

  -- Перекладываем навых шахтёра, если есть
  declare
    v_skill integer := json.get_integer_opt(data.get_attribute_value(v_person_id, 'system_person_miner_skill'), null);
  begin
    if v_skill is not null then
      perform data.set_attribute_value(data.get_object_id('mine_person'), 'miner_skill', to_jsonb(v_skill), v_person_id);
    end if;
  end;

  return v_person_id;
end;
$$
language plpgsql;
