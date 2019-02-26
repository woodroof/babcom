-- drop function pallas_project.init_economics();

create or replace function pallas_project.init_economics()
returns void
volatile
as
$$
begin
  insert into data.params(code, value) values
  ('economic_cycle_number', jsonb '1'),
  ('coin_price', jsonb '10'),
  ('life_support_status_prices', jsonb '[6, 1, 1]'),
  ('health_care_status_prices', jsonb '[1, 6, 8]'),
  ('recreation_status_prices', jsonb '[2, 4, 4]'),
  ('police_status_prices', jsonb '[1, 5, 6]'),
  ('administrative_services_status_prices', jsonb '[2, 6, 7]'),
  ('base_un_coins', jsonb '12'),
  ('base_un_rating', jsonb '150');

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
  ('cycle', null, 'Текущий экономический цикл', 'normal', null, 'pallas_project.vd_cycle', false),
  ('contract_org', 'Заказчик', null, 'normal', null, 'pallas_project.vd_link', false),
  ('contract_person', 'Исполнитель', null, 'normal', null, 'pallas_project.vd_link', false),
  ('contract_status', 'Статус контракта', null, 'normal', null, 'pallas_project.vd_contract_status', false),
  ('contract_reward', 'Вознаграждение за цикл', null, 'normal', 'full', 'pallas_project.vd_money', false),
  ('contract_description', 'Условия', null, 'normal', 'full', null, false);

  insert into data.actions(code, function) values
  ('cancel_contract_immediate', 'pallas_project.act_cancel_contract_immediate'),
  ('cancel_contract', 'pallas_project.act_cancel_contract'),
  ('edit_contract', 'pallas_project.act_edit_contract'),
  ('confirm_contract', 'pallas_project.act_confirm_contract'),
  ('suspend_contract', 'pallas_project.act_suspend_contract'),
  ('unsuspend_contract', 'pallas_project.act_unsuspend_contract'),
  ('buy_status', 'pallas_project.act_buy_status'),
  ('create_contract', 'pallas_project.act_create_contract'),
  ('contract_draft_edit', 'pallas_project.act_contract_draft_edit'),
  ('contract_draft_cancel', 'pallas_project.act_contract_draft_cancel'),
  ('contract_draft_confirm', 'pallas_project.act_contract_draft_confirm');

  -- Классы для статусов
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
      {"code": "independent_from_actor_list_elements", "value": true},
      {"code": "independent_from_object_list_elements", "value": true},
      {"code": "title", "value": "Статусы"},
      {"code": "template", "value": {"title": "title", "subtitle": "cycle", "groups": []}}
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

  -- Классы для контрактов
  perform data.create_class(
    'contract',
    jsonb '[
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {"code": "type", "value": "contract"},
      {"code": "title", "value": "Контракт"},
      {"code": "actions_function", "value": "pallas_project.actgenerator_contract"},
      {
        "code": "mini_card_template",
        "value": {
          "groups": [
            {"code": "group", "attributes": ["contract_org", "contract_person", "contract_status"]}
          ]
        }
      },
      {
        "code": "template",
        "value": {
          "title": "title",
          "groups": [
            {
              "code": "group",
              "actions": ["confirm_contract", "edit_contract", "cancel_contract", "suspend_contract", "unsuspend_contract", "cancel_contract_immediate"],
              "attributes": ["contract_org", "contract_person", "contract_status", "contract_reward", "contract_description"]
            }
          ]
        }
      }
    ]');
  perform data.create_class(
    'contract_list',
    jsonb '[
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {"code": "type", "value": "contract_list"},
      {"code": "actions_function", "value": "pallas_project.actgenerator_contract_list"},
      {"code": "independent_from_actor_list_elements", "value": true},
      {"code": "independent_from_object_list_elements", "value": true},
      {
        "code": "template",
        "value": {
          "title": "title",
          "groups": [
            {"code": "group", "actions": ["create_contract"]}
          ]
        }
      }
    ]');
  perform data.create_object(
    'contracts',
    jsonb '{
      "title": "Все контакты",
      "content": []
    }',
    'contract_list');
  perform data.create_class(
    'contract_draft',
    jsonb '[
      {"code": "type", "value": "contract_draft"},
      {"code": "title", "value": "Создание контракта"},
      {"code": "temporary_object", "value": true},
      {"code": "actions_function", "value": "pallas_project.actgenerator_contract_draft"},
      {
        "code": "template",
        "value": {
          "title": "title",
          "groups": [
            {
              "code": "group",
              "actions": ["contract_draft_edit", "contract_draft_cancel", "contract_draft_confirm"],
              "attributes": ["contract_org", "contract_person", "contract_reward", "contract_description"]
            }
          ]
        }
      }
    ]');
  perform data.create_class(
    'contract_person_list',
    jsonb '[
      {"code": "title", "value": "Выбор исполнителя"},
      {"code": "type", "value": "contract_person_list"},
      {"code": "list_element_function", "value": "pallas_project.lef_contract_person_list"},
      {"code": "temporary_object", "value": true},
      {"code": "independent_from_actor_list_elements", "value": true},
      {"code": "independent_from_object_list_elements", "value": true},
      {
        "code": "template",
        "value": {
          "title": "title",
          "groups": [
            {"code": "group", "actions": []}
          ]
        }
      }
    ]');
end;
$$
language plpgsql;
