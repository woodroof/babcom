-- drop function pallas_project.init_debatles();

create or replace function pallas_project.init_debatles()
returns void
volatile
as
$$
declare
  v_type_attribute_id integer := data.get_attribute_id('type');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_actions_function_attribute_id integer := data.get_attribute_id('actions_function');

  v_debatles_id integer;
  v_debatles_all_id integer;
  v_debatles_new_id integer;
  v_debatles_my_id integer;
  v_debatles_future_id integer;
  v_debatles_closed_id integer;

  v_master_group_id integer := data.get_object_id('master');

begin
  -- Атрибуты для дебатла
  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden) values
  ('debatle_status', 'Статус дебатла', 'normal', null, 'pallas_project.vd_debatle_status', false),
  ('system_debatle_person1', 'Идентификатор первого участника дебатла', 'system', null, null, false),
  ('debatle_person1', 'Первый участник дебатла', 'normal', 'full', null, false),
  ('system_debatle_person2', 'Идентификатор второго участника дебатла', 'system', null, null, false),
  ('debatle_person2', 'Второй участник дебатла', 'normal', 'full', null, false),
  ('system_debatle_judge', 'Идентификатор судьи', 'system', null, null, false),
  ('debatle_judge', 'Судья', 'normal', 'full', null, false),
  ('system_debatle_target_audience', 'Аудитория дебатла', 'system', null, null, false),
  ('debatle_target_audience', 'Аудитория дебатла', 'normal', 'full', null, true),
  ('system_debatle_person1_votes', 'Количество голосов за первого участника', 'system', null, null, false),
  ('debatle_person1_votes', 'Количество голосов за первого участника', 'normal', 'full', null, true),
  ('system_debatle_person2_votes', 'Количество голосов за второго участника', 'system', null, null, false),
  ('debatle_person2_votes', 'Количество голосов за второго участника', 'normal', 'full', null, true),
  ('debatle_vote_price', 'Стоимость голосования', 'normal', 'full', null, true),
  ('system_debatle_person1_bonuses', 'Бонусы первого участника', 'system', null, null, false),
  ('debatle_person1_bonuses', 'Бонусы первого участника', 'normal', 'full', null, true),
  ('system_debatle_person1_fines' , 'Штрафы первого участника', 'system', null, null, false),
  ('debatle_person1_fines', 'Штрафы первого участника', 'normal', 'full', null, true),
  ('system_debatle_person2_bonuses', 'Бонусы второго участника', 'system', null, null, false),
  ('debatle_person2_bonuses', 'Бонусы второго участника', 'normal', 'full', null, true),
  ('system_debatle_person2_fines' , 'Штрафы второго участника', 'system', null, null, false),
  ('debatle_person2_fines', 'Штрафы второго участника', 'normal', 'full', null, true);

  insert into data.actions(code, function) values
  ('create_debatle_step1', 'pallas_project.act_create_debatle_step1');

-- Объект - страница для работы с дебатлами
  insert into data.objects(code) values('debatles') returning id into v_debatles_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_debatles_id, v_type_attribute_id, jsonb '"debatles"'),
  (v_debatles_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_debatles_id, v_title_attribute_id, jsonb '"Дебатлы"'),
  (v_debatles_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_debatles"');

  -- Списки дебатлов
  insert into data.objects(code) values ('debatles_all') returning id into v_debatles_all_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_all_id, v_type_attribute_id, jsonb '"debatle_list"', null),
  (v_debatles_all_id, v_title_attribute_id, jsonb '"Все дебатлы"', null),
  (v_debatles_all_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id);

  insert into data.objects(code) values ('debatles_new') returning id into v_debatles_new_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_new_id, v_type_attribute_id, jsonb '"debatle_list"', null),
  (v_debatles_new_id, v_title_attribute_id, jsonb '"Несогласованные дебатлы"', null),
  (v_debatles_new_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id);

  insert into data.objects(code) values ('debatles_my') returning id into v_debatles_my_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_my_id, v_type_attribute_id, jsonb '"debatle_list"', null),
  (v_debatles_my_id, v_title_attribute_id, jsonb '"Мои дебатлы"', null),
  (v_debatles_my_id, v_is_visible_attribute_id, jsonb 'true', null);

  insert into data.objects(code) values ('debatles_future') returning id into v_debatles_future_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_future_id, v_type_attribute_id, jsonb '"debatle_list"', null),
  (v_debatles_future_id, v_title_attribute_id, jsonb '"Cогласованные дебатлы"', null),
  (v_debatles_future_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id);

  insert into data.objects(code) values ('debatles_closed') returning id into v_debatles_closed_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_closed_id, v_type_attribute_id, jsonb '"debatle_list"', null),
  (v_debatles_closed_id, v_title_attribute_id, jsonb '"Завершенные дебатлы"', null),
  (v_debatles_closed_id, v_is_visible_attribute_id, jsonb 'true', null);
end;
$$
language 'plpgsql';
