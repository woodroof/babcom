-- drop function pallas_project.init_second_characters();

create or replace function pallas_project.init_second_characters()
returns void
volatile
as
$$
declare
  v_original_person_id integer;
  v_person_id integer;
begin
  v_original_person_id := data.get_object_id('0d07f15b-2952-409b-b22e-4042cf70acc6');
  v_person_id :=
    pallas_project.create_person(
      '09c74928-0cf8-4c15-b9a9-aef481b438e6',
      null,
      format(
        '{
          "title":"Элтон Спирс",
          "description":"Астер.",
          "system_money":90,
          "person_district":"sector_E",
          "person_occupation":"Сантехник",
          "person_opa_rating":1,
          "system_person_economy_type":"asters",
          "system_person_deposit_money":31,
          "system_person_police_status":0,
          "system_person_recreation_status":0,
          "system_person_health_care_status":0,
          "system_person_life_support_status":1,
          "system_person_administrative_services_status":0,
          "system_person_original_id":%s
        }',
        v_original_person_id)::jsonb,
      array['all_person', 'player', 'aster']);

  insert into data.login_actors(login_id, actor_id, is_main)
  select login_id, v_person_id, false
  from data.login_actors
  where actor_id = v_original_person_id;

  v_original_person_id := data.get_object_id('c9e08512-e729-430a-b2fd-df8e7c94a5e7');
  v_person_id :=
    pallas_project.create_person(
      null,
      null,
      format(
        '{
          "title":"Чарльз Эшфорд",
          "system_money":2000,
          "system_person_economy_type":"fixed_with_money",
          "system_person_police_status":0,
          "system_person_recreation_status":0,
          "system_person_health_care_status":0,
          "system_person_life_support_status":0,
          "system_person_administrative_services_status":0,
          "system_person_original_id":%s
        }',
        v_original_person_id)::jsonb,
      array['all_person']);

  insert into data.login_actors(login_id, actor_id, is_main)
  select login_id, v_person_id, false
  from data.login_actors
  where actor_id = v_original_person_id;

  v_original_person_id := data.get_object_id('939b6537-afc1-41f4-963a-21ccfd1c7d28');
  v_person_id :=
    pallas_project.create_person(
      null,
      null,
      format(
        '{
          "title":"Руперт Мёрдок",
          "person_state":"un",
          "person_un_rating":450,
          "system_person_economy_type":"fixed",
          "system_person_police_status":3,
          "system_person_recreation_status":2,
          "system_person_health_care_status":2,
          "system_person_life_support_status":2,
          "system_person_administrative_services_status":3,
          "system_person_original_id":%s
        }',
        v_original_person_id)::jsonb,
      array['all_person']);

  insert into data.login_actors(login_id, actor_id, is_main)
  select login_id, v_person_id, false
  from data.login_actors
  where actor_id = v_original_person_id;

  v_original_person_id := data.get_object_id('6dc0a14a-a63f-44aa-a677-e5376490f28d');
  v_person_id :=
    pallas_project.create_person(
      null,
      null,
      format(
        '{
          "title":"Алекс Камаль",
          "person_state":"mcr",
          "system_money":10000,
          "system_person_economy_type":"fixed_with_money",
          "system_person_police_status":3,
          "system_person_recreation_status":3,
          "system_person_health_care_status":3,
          "system_person_life_support_status":3,
          "system_person_administrative_services_status":3,
          "system_person_original_id":%s
        }',
        v_original_person_id)::jsonb,
      array['all_person']);

  insert into data.login_actors(login_id, actor_id, is_main)
  select login_id, v_person_id, false
  from data.login_actors
  where actor_id = v_original_person_id;
end;
$$
language plpgsql;
