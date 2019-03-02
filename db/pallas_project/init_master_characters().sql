-- drop function pallas_project.init_master_characters();

create or replace function pallas_project.init_master_characters()
returns void
volatile
as
$$
declare
  v_master_characters integer[] := array[]::integer[];
  v_master_login_id integer;
  v_char_id integer;
begin
  v_char_id :=
    pallas_project.create_person(
      'asj',
      null,
      jsonb '{
        "title": "АСС",
        "person_occupation": "Автоматическая система судопроизводства"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);

  -- Сантьяго де ла Крус - большой картель
  -- todo

  -- Привязываем эти персонажи ко всем мастерам
  insert into data.login_actors(login_id, actor_id, is_main)
  select login_id, new_actor_id, false
  from data.login_actors la
  join unnest(v_master_characters) a(new_actor_id) on true
  where la.actor_id in (
    select object_id
    from data.object_objects
    where
      parent_object_id = data.get_object_id('master') and
      parent_object_id != object_id);
end;
$$
language plpgsql;
