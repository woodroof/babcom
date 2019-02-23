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
  ('system_person_coin', null, 'system', null, null, false),
  ('person_coin', 'Нераспределённые коины', 'normal', 'full', null, true),
  ('person_opa_rating', 'Популярность среди астеров', 'normal', 'full', 'pallas_project.vd_person_opa_rating', true),
  ('person_un_rating', 'Рейтинг в ООН', 'normal', 'full', null, true),
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
  ('system_person_next_life_support_status', null, 'system', null, null, false),
  ('system_person_next_health_care_status', null, 'system', null, null, false),
  ('system_person_next_recreation_status', null, 'system', null, null, false),
  ('system_person_next_police_status', null, 'system', null, null, false),
  ('system_person_next_administrative_services_status', null, 'system', null, null, false),
  ('system_person_notification_count', null, 'system', null, null, false),
  ('person_district', 'Район проживания', 'normal', 'full', 'pallas_project.vd_link', false);

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
              "transfer_money"
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

  -- Мастера
  perform pallas_project.create_person('m1', jsonb '{"title": "Саша", "person_occupation": "Мастер"}', array['master']);
  perform pallas_project.create_person('m2', jsonb '{"title": "Петя", "person_occupation": "Мастер"}', array['master']);
  perform pallas_project.create_person('m3', jsonb '{"title": "Данил", "person_occupation": "Мастер"}', array['master']);
  perform pallas_project.create_person('m4', jsonb '{"title": "Нина", "person_occupation": "Мастер"}', array['master']);
  perform pallas_project.create_person('m5', jsonb '{"title": "Оля", "person_occupation": "Мастер"}', array['master']);
  perform pallas_project.create_person('m6', jsonb '{"title": "Юра", "person_occupation": "Мастер"}', array['master']);

  -- Игроки
  perform pallas_project.create_person(
    'p1',
    jsonb '{
      "title": "Джерри Адамс",
      "person_occupation": "Секретарь администрации",
      "person_state": "un",
      "system_person_coin": 25,
      "person_opa_rating": 1,
      "person_un_rating": 150,
      "system_person_economy_type": "un",
      "system_person_life_support_status": 3,
      "system_person_health_care_status": 3,
      "system_person_recreation_status": 2,
      "system_person_police_status": 3,
      "system_person_administrative_services_status": 3,
      "person_district": "sector_A"}',
    array['all_person', 'un', 'player']);
  perform pallas_project.create_person(
    'p2',
    jsonb '{
      "title": "Сьюзан Сидорова",
      "person_occupation": "Шахтёр",
      "system_money": 25000,
      "system_person_deposit_money": 100000,
      "person_opa_rating": 5,
      "system_person_economy_type": "asters",
      "system_person_life_support_status": 2,
      "system_person_health_care_status": 1,
      "system_person_recreation_status": 2,
      "system_person_police_status": 1,
      "system_person_administrative_services_status": 1,
      "person_district": "sector_E"}',
    array['all_person', 'opa', 'player', 'aster']);
  perform pallas_project.create_person(
    'p3',
    jsonb '{
      "title": "Чарли Чандрасекар",
      "person_occupation": "Главный экономист",
      "person_state": "un",
      "system_person_coin": 25,
      "person_opa_rating": 1,
      "person_un_rating": 200,
      "system_person_economy_type": "un",
      "system_person_life_support_status": 3,
      "system_person_health_care_status": 3,
      "system_person_recreation_status": 2,
      "system_person_police_status": 3,
      "system_person_administrative_services_status": 3,
      "person_district": "sector_B"}',
    array['all_person', 'un', 'player']);
  perform pallas_project.create_person(
    'p4',
    jsonb '{
      "title": "Алисия Сильверстоун",
      "person_occupation": "Специалист по сейсморазведке",
      "system_money": 25000,
      "system_person_deposit_money": 100000,
      "person_opa_rating": 1,
      "system_person_economy_type": "asters",
      "system_person_life_support_status": 2,
      "system_person_health_care_status": 1,
      "system_person_recreation_status": 2,
      "system_person_police_status": 1,
      "system_person_administrative_services_status": 1,
      "person_district": "sector_D"}',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    'p5',
    jsonb '{
      "title": "Амели Сноу",
      "person_occupation": "Бригадир грузчиков",
      "system_money": 25000,
      "system_person_deposit_money": 100000,
      "person_opa_rating": 2,
      "system_person_economy_type": "asters",
      "system_person_life_support_status": 2,
      "system_person_health_care_status": 1,
      "system_person_recreation_status": 2,
      "system_person_police_status": 1,
      "system_person_administrative_services_status": 1,
      "person_district": "sector_G"}',
    array['all_person', 'player', 'aster']);

  -- Игротехнические персонажи и тайные личности
  -- Сантьяго де ла Крус - большой картель

  perform pallas_project.create_person(
    'p10',
    jsonb '{
      "title": "АСС",
      "person_occupation": "Автоматическая система судопроизводства"}',
    array['all_person']);

  perform pallas_project.create_person(
    'p11',
    jsonb '{
      "title": "Шенг",
      "person_occupation": "Репортёр",
      "system_person_economy_type": "fixed",
      "system_person_life_support_status": 2,
      "system_person_health_care_status": 2,
      "system_person_recreation_status": 2,
      "system_person_police_status": 2,
      "system_person_administrative_services_status": 2,
      "person_district": "sector_D"}',
    array['all_person']);
end;
$$
language plpgsql;
