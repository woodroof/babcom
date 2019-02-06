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

  v_person_class_id integer;
begin
  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden) values
  ('person_occupation', 'Должность', 'normal', null, null, true),
  ('person_state', 'Гражданство', 'normal', 'full', 'pallas_project.vd_person_state', true),
  ('system_money', 'Остаток средств на счёте', 'system', null, null, false),
  ('money', 'Остаток средств на счёте', 'normal', 'full', null, true),
  ('system_person_deposit_money', 'Остаток средств на накопительном счёте', 'system', null, null, false),
  ('person_deposit_money', 'Остаток средств на накопительном счёте', 'normal', 'full', null, true),
  ('system_person_coin', 'Остаток коинов', 'system', null, null, false),
  ('person_coin', 'Остаток коинов', 'normal', 'full', null, true),
  ('system_person_opa_rating', 'Рейтинг в СВП', 'system', null, null, false),
  ('person_opa_rating', 'Рейтинг в СВП', 'normal', 'full', null, true),
  ('system_person_un_rating', 'Рейтинг в ООН', 'system', null, null, false),
  ('person_un_rating', 'Рейтинг в ООН', 'normal', 'full', null, true),
  ('system_person_economy_type', 'Тип экономики', 'system', null, null, false),
  ('person_economy_type', 'Тип экономики', 'normal', 'full', 'pallas_project.vd_person_economy_type', true),
  ('system_person_life_support_status', 'Жизнеобеспечение', 'system', null, null, false),
  ('person_life_support_status', 'Жизнеобеспечение', 'normal', 'full', 'pallas_project.vd_person_status', true),
  ('system_person_health_care_status', 'Медицина', 'system', null, null, false),
  ('person_health_care_status', 'Медицина', 'normal', 'full', 'pallas_project.vd_person_status', true),
  ('system_person_recreation_status', 'Развлечения', 'system', null, null, false),
  ('person_recreation_status', 'Развлечения', 'normal', 'full', 'pallas_project.vd_person_status', true),
  ('system_person_police_status', 'Полиция', 'system', null, null, false),
  ('person_police_status', 'Полиция', 'normal', 'full', 'pallas_project.vd_person_status', true),
  ('system_person_administrative_services_status', 'Административное обслуживание', 'system', null, null, false),
  ('person_administrative_services_status', 'Административное обслуживание', 'normal', 'full', 'pallas_project.vd_person_status', true),
  ('system_person_next_life_support_status', null, 'system', null, null, false),
  ('system_person_next_health_care_status', null, 'system', null, null, false),
  ('system_person_next_recreation_status', null, 'system', null, null, false),
  ('system_person_next_police_status', null, 'system', null, null, false),
  ('system_person_next_administrative_services_status', null, 'system', null, null, false);

  --Объект класса для персон
  insert into data.objects(code, type) values('person', 'class') returning id into v_person_class_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_class_id, v_type_attribute_id, jsonb '"person"'),
  (v_person_class_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_person_class_id, v_priority_attribute_id, jsonb '200'),
  (v_person_class_id, v_full_card_function_attribute_id, jsonb '"pallas_project.fcard_person"'),
  (v_person_class_id, v_mini_card_function_attribute_id, jsonb '"pallas_project.mcard_person"'),
  (v_person_class_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_person"'),
  (
    v_person_class_id,
    v_template_attribute_id,
    jsonb '{
      "groups": [
        {
          "code": "person_personal",
          "attributes": [
            "person_economy_type",
            "money",
            "person_deposit_money",
            "person_coin",
            "person_opa_rating",
            "person_un_rating"
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
            "person_occupation",
            "description"
          ]
        }
      ]
    }'
  );

  -- Группы персон
  declare
    v_all_person_group_id integer;
    v_aster_group_id integer;
    v_un_group_id integer;
    v_mcr_group_id integer;
    v_opa_group_id integer;
    v_master_group_id integer;
    v_player_group_id integer;
  begin
    insert into data.objects(code) values ('all_person') returning id into v_all_person_group_id;
    insert into data.objects(code) values ('aster') returning id into v_aster_group_id;
    insert into data.objects(code) values ('un') returning id into v_un_group_id;
    insert into data.objects(code) values ('mcr') returning id into v_mcr_group_id;
    insert into data.objects(code) values ('opa') returning id into v_opa_group_id;
    insert into data.objects(code) values ('master') returning id into v_master_group_id;
    insert into data.objects(code) values ('player') returning id into v_player_group_id;

    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_all_person_group_id, v_priority_attribute_id, jsonb '10'),
    (v_player_group_id, v_priority_attribute_id, jsonb '15'),
    (v_aster_group_id, v_priority_attribute_id, jsonb '20'),
    (v_un_group_id, v_priority_attribute_id, jsonb '30'),
    (v_mcr_group_id, v_priority_attribute_id, jsonb '40'),
    (v_opa_group_id, v_priority_attribute_id, jsonb '50'),
    (v_master_group_id, v_priority_attribute_id, jsonb '190');
  end;

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
      "system_person_coin": 50,
      "system_person_opa_rating": 1,
      "system_person_un_rating": 150,
      "system_person_economy_type": "un",
      "system_person_life_support_status": 3,
      "system_person_health_care_status": 3,
      "system_person_recreation_status": 2,
      "system_person_police_status": 3,
      "system_person_administrative_services_status": 3}',
    array['all_person', 'un', 'player']);
  perform pallas_project.create_person(
    'p2',
    jsonb '{
      "title": "Сьюзан Сидорова",
      "person_occupation": "Шахтёр",
      "system_money": 65000,
      "system_person_opa_rating": 5,
      "system_person_economy_type": "un",
      "system_person_life_support_status": 2,
      "system_person_health_care_status": 1,
      "system_person_recreation_status": 2,
      "system_person_police_status": 1,
      "system_person_administrative_services_status": 1}',
    array['all_person', 'opa', 'player', 'aster']);
  perform pallas_project.create_person(
    'p3',
    jsonb '{
      "title": "Чарли Чандрасекар",
      "person_occupation": "Главный экономист",
      "person_state": "un",
      "system_person_coin": 50,
      "system_person_opa_rating": 1,
      "system_person_un_rating": 200,
      "system_person_economy_type": "un",
      "system_person_life_support_status": 3,
      "system_person_health_care_status": 3,
      "system_person_recreation_status": 2,
      "system_person_police_status": 3,
      "system_person_administrative_services_status": 3}',
    array['all_person', 'un', 'player']);
end;
$$
language plpgsql;
