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
  v_template_attribute_id integer := data.get_attribute_id('template');
  v_full_card_function_attribute_id integer := data.get_attribute_id('full_card_function');
  v_mini_card_function_attribute_id integer := data.get_attribute_id('mini_card_function');
  v_list_element_function_attribute_id integer := data.get_attribute_id('list_element_function');
  v_temporary_object_attribute_id integer := data.get_attribute_id('temporary_object');


  v_debatles_id integer;
  v_debatle_list_class_id integer;
  v_debatles_all_id integer;
  v_debatles_new_id integer;
  v_debatles_my_id integer;
  v_debatles_future_id integer;
  v_debatles_closed_id integer;
  v_debatles_current_id integer;

  v_debatle_class_id integer;
  v_debatle_temp_person_list_class_id integer;

  v_master_group_id integer := data.get_object_id('master');

begin
  -- Атрибуты для дебатла
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('system_debatle_theme', null, 'Тема дебатла', 'system', null, null, false),
  ('debatle_status', 'Статус дебатла', null, 'normal', null, 'pallas_project.vd_debatle_status', false),
  ('system_debatle_person1', null, 'Идентификатор первого участника дебатла', 'system', null, null, false),
  ('debatle_person1', 'Первый участник дебатла', null, 'normal', 'full', null, false),
  ('system_debatle_person2', null, 'Идентификатор второго участника дебатла', 'system', null, null, false),
  ('debatle_person2', 'Второй участник дебатла', null, 'normal', 'full', null, false),
  ('system_debatle_judge', null, 'Идентификатор судьи', 'system', null, null, false),
  ('debatle_judge', 'Судья', null, 'normal', 'full', null, false),
  ('system_debatle_target_audience', null, 'Аудитория дебатла', 'system', null, null, false),
  ('debatle_target_audience', 'Аудитория дебатла', null, 'normal', 'full', null, true),
  ('system_debatle_person1_votes', null, 'Количество голосов за первого участника', 'system', null, null, false),
  ('debatle_person1_votes', 'Количество голосов за первого участника', null, 'normal', 'full', null, true),
  ('system_debatle_person2_votes', null, 'Количество голосов за второго участника', 'system', null, null, false),
  ('debatle_person2_votes', 'Количество голосов за второго участника', null, 'normal', 'full', null, true),
  ('debatle_vote_price', 'Стоимость голосования', null, 'normal', 'full', null, true),
  ('system_debatle_person1_bonuses', null, 'Бонусы первого участника', 'system', null, null, false),
  ('debatle_person1_bonuses', 'Бонусы первого участника', null, 'normal', 'full', null, true),
  ('system_debatle_person1_fines' , null, 'Штрафы первого участника', 'system', null, null, false),
  ('debatle_person1_fines', 'Штрафы первого участника', null, 'normal', 'full', null, true),
  ('system_debatle_person2_bonuses', null, 'Бонусы второго участника', 'system', null, null, false),
  ('debatle_person2_bonuses', 'Бонусы второго участника', null, 'normal', 'full', null, true),
  ('system_debatle_person2_fines', null, 'Штрафы второго участника', 'system', null, null, false),
  ('debatle_person2_fines', 'Штрафы второго участника', null, 'normal', 'full', null, true),
  -- для временных объектов 
  ('debatle_temp_person_list_edited_person', null, 'Редактируемая персона в дебатле', 'normal', 'full', 'pallas_project.vd_debatle_temp_person_list_edited_person', false),
  ('system_debatle_temp_person_list_debatle_id', null, 'Идентификатор дебатла для списка редактирования персон', 'system', null, null, false);

-- Объект - страница для работы с дебатлами
  insert into data.objects(code) values('debatles') returning id into v_debatles_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_debatles_id, v_type_attribute_id, jsonb '"debatles"'),
  (v_debatles_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_debatles_id, v_title_attribute_id, jsonb '"Дебатлы"'),
  (v_debatles_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_debatles"'),
  (v_debatles_id, v_template_attribute_id, jsonb_build_object('groups', array[format(
                                          '{"code": "%s", "attributes": ["%s"], "actions": ["%s", "%s", "%s", "%s", "%s", "%s", "%s"]}',
                                          'debatles_group1',
                                          'description',
                                          'create_debatle_step1',
                                          'get_new_debatles',
                                          'get_current_debatles',
                                          'get_future_debatles',
                                          'get_my_debatles',
                                          'get_closed_debatles',
                                          'get_all_debatles')::jsonb]));

    -- Объект-класс для списка дебатлов
  insert into data.objects(code, type) values('debatle_list', 'class') returning id into v_debatle_list_class_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_debatle_list_class_id, v_type_attribute_id, jsonb '"debatle_list"'),
  (v_debatle_list_class_id, v_template_attribute_id, jsonb_build_object('groups', array[]::text[]));


  -- Списки дебатлов
  insert into data.objects(code, class_id) values ('debatles_all', v_debatle_list_class_id) returning id into v_debatles_all_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_all_id, v_title_attribute_id, jsonb '"Все дебатлы"', null),
  (v_debatles_all_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id);

  insert into data.objects(code, class_id) values ('debatles_new', v_debatle_list_class_id) returning id into v_debatles_new_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_new_id, v_title_attribute_id, jsonb '"Неподтверждённые дебатлы"', null),
  (v_debatles_new_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id);

  insert into data.objects(code, class_id) values ('debatles_my', v_debatle_list_class_id) returning id into v_debatles_my_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_my_id, v_title_attribute_id, jsonb '"Мои дебатлы"', null),
  (v_debatles_my_id, v_is_visible_attribute_id, jsonb 'true', null);

  insert into data.objects(code, class_id) values ('debatles_future', v_debatle_list_class_id) returning id into v_debatles_future_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_future_id, v_title_attribute_id, jsonb '"Будущие дебатлы"', null),
  (v_debatles_future_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id);

  insert into data.objects(code, class_id) values ('debatles_current', v_debatle_list_class_id) returning id into v_debatles_current_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_current_id, v_title_attribute_id, jsonb '"Текущие дебатлы"', null),
  (v_debatles_current_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id);

  insert into data.objects(code, class_id) values ('debatles_closed', v_debatle_list_class_id) returning id into v_debatles_closed_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_closed_id, v_title_attribute_id, jsonb '"Завершенные дебатлы"', null),
  (v_debatles_closed_id, v_is_visible_attribute_id, jsonb 'true', null);

  -- Объект-класс для дебатла
  insert into data.objects(code, type) values('debatle', 'class') returning id into v_debatle_class_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_debatle_class_id, v_type_attribute_id, jsonb '"debatle"'),
  (v_debatle_class_id, v_full_card_function_attribute_id, jsonb '"pallas_project.fcard_debatle"'),
  (v_debatle_class_id, v_mini_card_function_attribute_id, jsonb '"pallas_project.mcard_debatle"'),
  (v_debatle_class_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_debatle"'),
  (v_debatle_class_id, v_template_attribute_id, jsonb_build_object('groups', array[format(
                                                      '{"code": "%s", "attributes": ["%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s"], "actions": ["%s", "%s", "%s"]}',
                                                      'debatle_group1',
                                                      'debatle_theme',
                                                      'debatle_status',
                                                      'debatle_person1',
                                                      'debatle_person2',
                                                      'debatle_judge',
                                                      'debatle_target_audience',
                                                      'debatle_person1_votes',
                                                      'debatle_person2_votes',
                                                      'debatle_vote_price',
                                                      'debatle_person1_bonuses',
                                                      'debatle_person1_fines',
                                                      'debatle_person2_bonuses',
                                                      'debatle_person2_fines',
                                                      'debatle_change_instigator',
                                                      'debatle_change_opponent',
                                                      'debatle_change_judge')::jsonb]));

  -- Объект-класс для временных списков персон для редактирования дебатла
  insert into data.objects(code, type) values('debatle_temp_person_list', 'class') returning id into v_debatle_temp_person_list_class_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_debatle_temp_person_list_class_id, v_type_attribute_id, jsonb '"debatle_temp_person_list"'),
  (v_debatle_temp_person_list_class_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_debatle_temp_person_list"'),
  (v_debatle_temp_person_list_class_id, v_list_element_function_attribute_id, jsonb '"pallas_project.lef_debatle_temp_person_list"'),
  (v_debatle_temp_person_list_class_id, v_temporary_object_attribute_id, jsonb 'true'),
  (v_debatle_temp_person_list_class_id, v_template_attribute_id, jsonb_build_object('groups', format(
                                                      '[{"code": "%s", "actions": ["%s"]}, {"code": "%s", "attributes": ["%s"]}]',
                                                      'group1',
                                                      'debatle_change_person_back',
                                                      'group2',
                                                      'debatle_temp_person_list_edited_person')::jsonb));

  insert into data.actions(code, function) values
  ('create_debatle_step1', 'pallas_project.act_create_debatle_step1'),
  ('debatle_change_person', 'pallas_project.act_debatle_change_person');


end;
$$
language 'plpgsql';
