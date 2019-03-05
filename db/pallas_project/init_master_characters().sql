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

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Адам Уоррен",
        "person_occupation": "Секретарь Министерства ООН по делам колоний"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      'b7845724-0c9a-498e-8b2f-a01455c22399',
      '0d07f15b-2952-409b-b22e-4042cf70acc6',
      '9b956c40-7978-4b0a-993e-8373fe581761',
      '494dd323-d808-48e6-8971-cd8f18656ec0',
      '95a3dc9e-8512-44ab-9173-29f0f4fd6e05',
      '19b66636-cd8e-4733-8a3d-2f16346bb81e']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Сомешвар Агнихотри",
        "person_occupation": "Зам. начальника инвестиционного фонда ООН"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '0d07f15b-2952-409b-b22e-4042cf70acc6',
      'dc2505e8-9f8e-4a41-b42f-f1f348db8c99']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Лаура Трейс",
        "person_occupation": "Специалист по кибербезопасности"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '494dd323-d808-48e6-8971-cd8f18656ec0']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Эмери Лайонс",
        "person_occupation": "Менеджер по контролю филиалов Де Бирс"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '784e4126-8dd7-41a3-a916-0fdc53a31ce2']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Дэн Гатри",
        "person_occupation": "Специалист по поставке редких товаров"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      'a11d2240-3dce-4d75-bc52-46e98b07ff27']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Анна Краузе"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '09951000-d915-495d-867d-4d0e7ebfcf9c']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Стим Ганимед",
        "person_occupation": "Поставщик лекарственных препаратов"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '18ce44b8-5df9-4c84-8af4-b58b3f5e7b21']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Гэрри Бут",
        "person_occupation": "Менеджер по контролю филиалов Star Helix"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '48569d1d-5f01-410f-a67b-c5fe99d8dbc1',
      '2903429c-8f58-4f78-96f7-315246b17796']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Агата Куин"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '3a83fb3c-b954-4a04-aa6c-7a46d7bf9b8e',
      'a9e4bc61-4e10-4c9e-a7de-d8f61536f657']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Сантьяго де ла Крус"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '70e5db08-df47-4395-9f4a-15eef99b2b89']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Кеннет Грир",
        "person_occupation": "Менеджер по контролю филиалов Akira SC"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '939b6537-afc1-41f4-963a-21ccfd1c7d28']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Дана Скалли",
        "person_occupation": "Глава департамента безопасности при комитете по делам колоний ООН"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '939b6537-afc1-41f4-963a-21ccfd1c7d28']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Тамара Мёрдоки"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '939b6537-afc1-41f4-963a-21ccfd1c7d28']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Эйлин Андервуд",
        "person_occupation": "Менеджер по контролю медицинских организаций экстерриториальных владений ООН"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '54e94c45-ce2a-459a-8613-9b75e23d9b68']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Альберт Янг"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      'e0c49e51-779f-4f21-bb94-bbbad33bc6e2']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Квентин Кидман",
        "person_occupation": "Куратор, Теко Марс"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '8f7b1cc6-28cd-4fb1-8c81-e0ab1c0df5c9']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Ричард Ландау",
        "person_occupation": "Куратор"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '2ecb2a46-50f7-4e93-b340-2c9875287252']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Джоб Стюарт",
        "person_occupation": "Специалист по поставке редких товаров"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '2956e4b7-7b02-4ffd-a725-ea3390b9a1cc']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Игнат Назаров",
        "person_occupation": "Специалист по поставке редких товаров"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '2956e4b7-7b02-4ffd-a725-ea3390b9a1cc']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Мороний Смит-младший",
        "person_occupation": "Директор по связям Церкви Космической Выси с общественностью"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      'ac1b23d0-ba5f-4042-85d5-880a66254803']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Пол Экман",
        "person_occupation": "Куратор, транспортное подразделение космических войск МРК"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '2d912a30-6c35-4cef-9d74-94665ac0b476']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Джордж Бун",
        "person_occupation": "Советник"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '6dc0a14a-a63f-44aa-a677-e5376490f28d']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Дэвид Рид",
        "person_occupation": "Начальник семнадцатого отдела"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '457ea315-fc47-4579-a12b-fd7b91375ba8']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Крис Марвинг"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      'd6ed7fcb-2e68-40b3-b0ab-5f6f4edc2f19']);

  v_char_id :=
    pallas_project.create_person(
      null,
      null,
      jsonb '{
        "title": "Альфред Бестер",
        "person_occupation": "Директор Riders Digest"
      }',
      array['all_person']);
  v_master_characters := array_append(v_master_characters, v_char_id);
  perform pallas_project.create_chats_with_master_character(
    v_char_id,
    array[
      '82a7d37d-1067-4f21-a980-9c0665ce579c',
      '0815d2a6-c82c-476c-a3dd-ed70a3f59e91']);

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
