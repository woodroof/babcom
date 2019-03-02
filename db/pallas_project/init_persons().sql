-- drop function pallas_project.init_persons();

create or replace function pallas_project.init_persons()
returns void
volatile
as
$$
declare
  v_type_attribute_id integer := data.get_attribute_id('type');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_priority_attribute_id integer := data.get_attribute_id('priority');
  v_full_card_function_attribute_id integer := data.get_attribute_id('full_card_function');
  v_mini_card_function_attribute_id integer := data.get_attribute_id('mini_card_function');
  v_actions_function_attribute_id integer := data.get_attribute_id('actions_function');
  v_template_attribute_id integer := data.get_attribute_id('template');
begin
  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden) values
  ('person_occupation', 'Должность', 'normal', null, null, true),
  ('person_state', 'Гражданство', 'normal', 'full', 'pallas_project.vd_person_state', true),
  ('system_money', null, 'system', null, null, false),
  ('money', 'Остаток средств на счёте', 'normal', 'full', 'pallas_project.vd_money', true),
  ('system_person_deposit_money', null, 'system', null, null, false),
  ('person_deposit_money', 'Остаток средств на инвестиционном счёте', 'normal', 'full', 'pallas_project.vd_money', true),
  ('system_person_coin_profit', null, 'system', null, null, false),
  ('system_person_coin', null, 'system', null, null, false),
  ('person_coin', 'Нераспределённые коины', 'normal', 'full', null, true),
  ('person_opa_rating', 'Популярность среди астеров', 'normal', 'full', 'pallas_project.vd_person_opa_rating', false),
  ('person_un_rating', 'Рейтинг в ООН', 'normal', 'full', null, false),
  ('system_person_economy_type', null, 'system', null, null, false),
  ('person_economy_type', 'Тип экономики', 'normal', 'full', 'pallas_project.vd_person_economy_type', true),
  ('system_person_life_support_status', null, 'system', null, null, false),
  ('person_life_support_status', 'Жизнеобеспечение', 'normal', 'full', 'pallas_project.vd_person_status', true),
  ('system_person_health_care_status', null, 'system', null, null, false),
  ('person_health_care_status', 'Медицина', 'normal', 'full', 'pallas_project.vd_person_status', true),
  ('system_person_recreation_status', null, 'system', null, null, false),
  ('person_recreation_status', 'Развлечения', 'normal', 'full', 'pallas_project.vd_person_status', true),
  ('system_person_police_status', null, 'system', null, null, false),
  ('person_police_status', 'Полиция', 'normal', 'full', 'pallas_project.vd_person_status', true),
  ('system_person_administrative_services_status', null, 'system', null, null, false),
  ('person_administrative_services_status', 'Административное обслуживание', 'normal', 'full', 'pallas_project.vd_person_status', true),
  ('system_person_notification_count', null, 'system', null, null, false),
  ('person_district', 'Район проживания', 'normal', 'full', 'pallas_project.vd_link', false),
  ('system_person_original_id', 'Идентификатор основной персоны', 'system', null, null, false),
  ('system_person_doubles_id_list', 'Список идентификаторов дублей персоны', 'system', null, null, false),
  ('system_person_is_stimulant_used', 'Признак, что принят стимулятор', 'system', null, null, false);

  insert into data.actions(code, function) values
  ('change_un_rating', 'pallas_project.act_change_un_rating'),
  ('change_opa_rating', 'pallas_project.act_change_opa_rating'),
  ('change_district', 'pallas_project.act_change_district');

  -- Объект класса для персон
  perform data.create_class(
    'person',
    jsonb '{
      "type": "person",
      "is_visible": true,
      "priority": 200,
      "actions_function": "pallas_project.actgenerator_person",
      "mini_card_template": {
        "title": "title",
        "subtitle": "person_occupation",
        "groups": [
          {
            "code": "person_mini_document",
            "actions": [
              "document_delete_signer", "document_sign_for_signer"
            ]
          }
        ]
      },
      "template": {
        "title": "title",
        "subtitle": "person_occupation",
        "groups": [
          {
            "code": "person_personal",
            "attributes": [
              "person_economy_type",
              "money",
              "person_deposit_money",
              "person_coin",
              "person_opa_rating",
              "person_un_rating",
              "person_district"
            ],
            "actions": [
              "open_current_statuses",
              "open_next_statuses",
              "open_transactions",
              "open_contracts",
              "transfer_money",
              "transfer_org_money1", "transfer_org_money2", "transfer_org_money3", "transfer_org_money4", "transfer_org_money5",
              "change_un_rating",
              "change_opa_rating",
              "change_district",
              "med_health"
            ]
          },
          {
            "code": "person_statuses",
            "name": "Текущие статусы",
            "attributes": [
              "person_life_support_status",
              "person_health_care_status",
              "person_recreation_status",
              "person_police_status",
              "person_administrative_services_status"
            ]
          },
          {
            "code": "person_public",
            "attributes": [
              "person_state",
              "description"
            ]
          }
        ]
      }
    }');

  -- Класс для личных организаций
  perform data.create_class(
    'my_organizations',
    jsonb '{
      "title": "Мои организации",
      "type": "organization_list",
      "independent_from_actor_list_elements": true,
      "independent_from_object_list_elements": true,
      "template": {
        "title": "title",
        "groups": []
      }
    }');

  -- Мастера
  perform pallas_project.create_person(null, 'm1', jsonb '{"title": "Саша", "person_occupation": "Мастер"}', array['master']);
  perform pallas_project.create_person(null, 'm2', jsonb '{"title": "Петя", "person_occupation": "Мастер"}', array['master']);
  perform pallas_project.create_person(null, 'm3', jsonb '{"title": "Данил", "person_occupation": "Мастер"}', array['master']);
  perform pallas_project.create_person(null, 'm4', jsonb '{"title": "Нина", "person_occupation": "Мастер"}', array['master']);
  perform pallas_project.create_person(null, 'm5', jsonb '{"title": "Оля", "person_occupation": "Мастер"}', array['master']);

  perform pallas_project.change_chat_person_list_on_person(data.get_object_id('master_chat'), null, true);

  -- Мастерские персонажи
  perform pallas_project.init_master_characters();

  -- Игроки
  perform pallas_project.init_players();
end;
$$
language plpgsql;
