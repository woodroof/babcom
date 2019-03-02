-- drop function pallas_project.init_players();

create or replace function pallas_project.init_players()
returns void
volatile
as
$$
begin
  perform pallas_project.create_person(
    'player1',
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
    'player2',
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
    'player3',
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
    array['all_person', 'un', 'player','doctor']);
  perform pallas_project.create_person(
    'player4',
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
    'player5',
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
end;
$$
language plpgsql;
