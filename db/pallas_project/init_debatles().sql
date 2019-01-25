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
  v_content_attribute_id integer := data.get_attribute_id('content');

  v_debatles_id integer;
  v_debatle_list_class_id integer;
  v_debatles_all_id integer;
  v_debatles_new_id integer;
  v_debatles_my_id integer;
  v_debatles_future_id integer;
  v_debatles_closed_id integer;
  v_debatles_current_id integer;
  v_debatles_draft_id integer;
  v_debatles_deleted_id integer;

  v_debatle_class_id integer;
  v_debatle_temp_person_list_class_id integer;

  v_debatle_temp_bonus_list_class_id integer;

  v_master_group_id integer := data.get_object_id('master');

begin
  -- Атрибуты для дебатла
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('system_debatle_theme', null, 'Тема дебатла', 'system', null, null, false),
  ('debatle_status', 'Статус', null, 'normal', null, 'pallas_project.vd_debatle_status', false),
  ('system_debatle_person1', null, 'Идентификатор первого участника дебатла', 'system', null, null, false),
  ('debatle_person1', 'Зачинщик', null, 'normal', 'full', null, false),
  ('system_debatle_person2', null, 'Идентификатор второго участника дебатла', 'system', null, null, false),
  ('debatle_person2', 'Оппонент', null, 'normal', 'full', null, false),
  ('system_debatle_judge', null, 'Идентификатор судьи', 'system', null, null, false),
  ('debatle_judge', 'Судья', null, 'normal', 'full', null, false),
  ('system_debatle_target_audience', null, 'Аудитория дебатла', 'system', null, null, false),
  ('debatle_target_audience', 'Аудитория', null, 'normal', 'full', null, true),
  ('system_debatle_person1_votes', null, 'Количество голосов за первого участника', 'system', null, null, false),
  ('debatle_person1_votes', null, 'Количество голосов за первого участника', 'normal', 'full', null, true),
  ('system_debatle_person2_votes', null, 'Количество голосов за второго участника', 'system', null, null, false),
  ('debatle_person2_votes', null, 'Количество голосов за второго участника', 'normal', 'full', null, true),
  ('debatle_vote_price', 'Стоимость голосования', null, 'normal', 'full', null, true),
  ('debatle_person1_bonuses', 'Штрафы и бонусы зачинщика', null, 'normal', 'full', 'pallas_project.vd_debatle_bonuses', false),
  ('debatle_person2_bonuses', 'Штрафы и бонусы оппонента', null, 'normal', 'full', 'pallas_project.vd_debatle_bonuses', false),
  ('system_debatle_person1_my_vote', null, 'Количество голосов каждого голосующего за первого участника', 'system', null, null, true),
  ('system_debatle_person2_my_vote', null, 'Количество голосов каждого голосующего за второго участника', 'system', null, null, true),
  ('debatle_my_vote', null, 'Уведомление игрока о том, за кого от проголосовал', 'normal', 'full', null, true),
  -- для временных объектов 
  ('debatle_temp_person_list_edited_person', null, 'Редактируемая персона в дебатле', 'normal', 'full', 'pallas_project.vd_debatle_temp_person_list_edited_person', false),
  ('system_debatle_temp_person_list_debatle_id', null, 'Идентификатор дебатла для списка редактирования персон', 'system', null, null, false);

-- Объект - страница для работы с дебатлами
  insert into data.objects(code) values('debatles') returning id into v_debatles_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_debatles_id, v_type_attribute_id, jsonb '"debatles"'),
  (v_debatles_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_debatles_id, v_title_attribute_id, jsonb '"Дебатлы"'),
  (v_debatles_id, v_full_card_function_attribute_id, jsonb '"pallas_project.fcard_debatles"'),
  (v_debatles_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_debatles"'),
  (v_debatles_id, v_template_attribute_id, jsonb_build_object('groups', array[format(
                                          '{"code": "%s", "attributes": ["%s"], "actions": ["%s"]}',
                                          'debatles_group1',
                                          'description',
                                          'create_debatle_step1')::jsonb]));

    -- Объект-класс для списка дебатлов
  insert into data.objects(code, type) values('debatle_list', 'class') returning id into v_debatle_list_class_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_debatle_list_class_id, v_type_attribute_id, jsonb '"debatle_list"'),
  (v_debatle_list_class_id, v_template_attribute_id, jsonb_build_object('groups', array[]::text[]));

  -- Списки дебатлов
  insert into data.objects(code, class_id) values ('debatles_all', v_debatle_list_class_id) returning id into v_debatles_all_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_all_id, v_title_attribute_id, jsonb '"Все дебатлы"', null),
  (v_debatles_all_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (v_debatles_all_id, v_content_attribute_id, jsonb '[]', null);

  insert into data.objects(code, class_id) values ('debatles_draft', v_debatle_list_class_id) returning id into v_debatles_draft_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_draft_id, v_title_attribute_id, jsonb '"Дебатлы черновики"', null),
  (v_debatles_draft_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (v_debatles_draft_id, v_content_attribute_id, jsonb '[]', null);

  insert into data.objects(code, class_id) values ('debatles_new', v_debatle_list_class_id) returning id into v_debatles_new_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_new_id, v_title_attribute_id, jsonb '"Неподтверждённые дебатлы"', null),
  (v_debatles_new_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (v_debatles_new_id, v_content_attribute_id, jsonb '[]', null);

  insert into data.objects(code, class_id) values ('debatles_my', v_debatle_list_class_id) returning id into v_debatles_my_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_my_id, v_title_attribute_id, jsonb '"Мои дебатлы"', null),
  (v_debatles_my_id, v_is_visible_attribute_id, jsonb 'true', null),
  (v_debatles_my_id, v_content_attribute_id, jsonb '[]', null);

  insert into data.objects(code, class_id) values ('debatles_future', v_debatle_list_class_id) returning id into v_debatles_future_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_future_id, v_title_attribute_id, jsonb '"Будущие дебатлы"', null),
  (v_debatles_future_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (v_debatles_future_id, v_content_attribute_id, jsonb '[]', null);

  insert into data.objects(code, class_id) values ('debatles_current', v_debatle_list_class_id) returning id into v_debatles_current_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_current_id, v_title_attribute_id, jsonb '"Текущие дебатлы"', null),
  (v_debatles_current_id, v_is_visible_attribute_id, jsonb 'true', null),
  (v_debatles_current_id, v_content_attribute_id, jsonb '[]', null);

  insert into data.objects(code, class_id) values ('debatles_closed', v_debatle_list_class_id) returning id into v_debatles_closed_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_closed_id, v_title_attribute_id, jsonb '"Завершенные дебатлы"', null),
  (v_debatles_closed_id, v_is_visible_attribute_id, jsonb 'true', null),
  (v_debatles_closed_id, v_content_attribute_id, jsonb '[]', null);

  insert into data.objects(code, class_id) values ('debatles_deleted', v_debatle_list_class_id) returning id into v_debatles_deleted_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_deleted_id, v_title_attribute_id, jsonb '"Удалённые дебатлы"', null),
  (v_debatles_deleted_id, v_is_visible_attribute_id, jsonb 'true', null),
  (v_debatles_deleted_id, v_content_attribute_id, jsonb '[]', null);

  -- Объект-класс для дебатла
  insert into data.objects(code, type) values('debatle', 'class') returning id into v_debatle_class_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_debatle_class_id, v_type_attribute_id, jsonb '"debatle"'),
  (v_debatle_class_id, v_full_card_function_attribute_id, jsonb '"pallas_project.fcard_debatle"'),
  (v_debatle_class_id, v_mini_card_function_attribute_id, jsonb '"pallas_project.mcard_debatle"'),
  (v_debatle_class_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_debatle"'),
  (v_debatle_class_id, v_template_attribute_id, jsonb_build_object('groups', array[format(
                                                      '{"code": "%s", "attributes": ["%s", "%s", "%s", "%s", "%s", "%s"], 
                                                                      "actions": ["%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s"]}',
                                                      'debatle_group1',
                                                      'debatle_theme',
                                                      'debatle_status',
                                                      'debatle_person1',
                                                      'debatle_person2',
                                                      'debatle_judge',
                                                      'debatle_target_audience',
                                                      'debatle_change_instigator',
                                                      'debatle_change_opponent',
                                                      'debatle_change_judge',
                                                      'debatle_change_theme',
                                                      'debatle_change_status_new',
                                                      'debatle_change_status_future',
                                                      'debatle_change_status_vote',
                                                      'debatle_change_status_vote_over',
                                                      'debatle_change_status_closed',
                                                      'debatle_change_status_deleted')::jsonb,
                                                      format(
                                                      '{"code": "%s", "attributes": ["%s", "%s", "%s", "%s"], 
                                                                      "actions": ["%s", "%s"]}',
                                                      'debatle_group2',
                                                      'debatle_person1_votes',
                                                      'debatle_person2_votes',
                                                      'debatle_vote_price',
                                                      'debatle_my_vote',
                                                      'debatle_vote_person1',
                                                      'debatle_vote_person2')::jsonb,
                                                      format(
                                                      '{"code": "%s", "attributes": ["%s", "%s"], 
                                                                      "actions": ["%s", "%s"]}',
                                                      'debatle_group3',
                                                      'debatle_person1_bonuses',
                                                      'debatle_person2_bonuses',
                                                      'debatle_change_bonuses1',
                                                      'debatle_change_bonuses2')::jsonb]));

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

  declare
    v_debatle_temp_bonus_list_class_id integer;
    v_debatle_bonus_class_id integer;
    v_debatle_bonus_votes_attribute_id integer;
    v_debatle_bonus_id integer;
  begin
    insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
    ('debatle_temp_bonus_list_person', null, 'Персона, которой начисляем бонусы и штрафы', 'normal', 'full', 'pallas_project.vd_debatle_temp_bonus_list_person', false),
    ('system_debatle_temp_bonus_list_debatle_id', null, 'Идентификатор дебатла для списка редактирования бонусов и штрафов', 'system', null, null, false),
    ('debatle_temp_bonus_list_bonuses', 'Уже имеющиеся бонусы и штрафы', 'Уже имеющиеся бонусы и штрафы', 'normal', 'full', 'pallas_project.vd_debatle_bonuses', false);

    -- Объект-класс для временных списков персон для редактирования бонусов и штрафов
    insert into data.objects(code, type) values('debatle_temp_bonus_list', 'class') returning id into v_debatle_temp_bonus_list_class_id;

    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_debatle_temp_bonus_list_class_id, v_type_attribute_id, jsonb '"debatle_temp_bonus_list"'),
    (v_debatle_temp_bonus_list_class_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_debatle_temp_bonus_list"'),
    (v_debatle_temp_bonus_list_class_id, v_list_element_function_attribute_id, jsonb '"pallas_project.lef_debatle_temp_bonus_list"'),
    (v_debatle_temp_bonus_list_class_id, v_temporary_object_attribute_id, jsonb 'true'),
    (v_debatle_temp_bonus_list_class_id, v_template_attribute_id, jsonb_build_object('groups', format(
                                                        '[{"code": "%s", "actions": ["%s"]}, {"code": "%s", "attributes": ["%s", "%s"], "actions": ["%s", "%s"]}]',
                                                        'group1',
                                                        'debatle_change_bonus_back',
                                                        'group2',
                                                        'debatle_temp_bonus_list_bonuses',
                                                        'debatle_temp_bonus_list_person',
                                                        'debatle_change_other_bonus',
                                                        'debatle_change_other_fine')::jsonb));

    -- Объекты для списка изменений бонусов и штрафов
    -- Класс
    insert into data.objects(code, type) values('debatle_bonus', 'class') returning id into v_debatle_bonus_class_id;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_debatle_bonus_class_id, v_type_attribute_id, jsonb '"debatle_bonus"'),
    (v_debatle_bonus_class_id, v_is_visible_attribute_id, jsonb 'true'),
    (v_debatle_bonus_class_id, v_template_attribute_id, jsonb_build_object('groups', format(
                                                      '[{"code": "%s", "attributes": ["%s"]}]',
                                                      'group1',
                                                      'debatle_bonus_votes')::jsonb));

    insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
    ('debatle_bonus_votes', 'Количество голосов' , 'Количество голосов бонуса или штрафа', 'normal', null, null, false) returning id into v_debatle_bonus_votes_attribute_id;

    insert into data.objects(code, class_id) values ('debatle_bonus_long', v_debatle_bonus_class_id) returning id into v_debatle_bonus_id;
    insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
    (v_debatle_bonus_id, v_title_attribute_id, jsonb '"затянутое выступление"', null),
    (v_debatle_bonus_id, v_debatle_bonus_votes_attribute_id, jsonb '-1', null);

    insert into data.objects(code, class_id) values ('debatle_bonus_confused', v_debatle_bonus_class_id) returning id into v_debatle_bonus_id;
    insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
    (v_debatle_bonus_id, v_title_attribute_id, jsonb '"сумбурное выступление"', null),
    (v_debatle_bonus_id, v_debatle_bonus_votes_attribute_id, jsonb '-1', null);

    insert into data.objects(code, class_id) values ('debatle_bonus_shout', v_debatle_bonus_class_id) returning id into v_debatle_bonus_id;
    insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
    (v_debatle_bonus_id, v_title_attribute_id, jsonb '"крик"', null),
    (v_debatle_bonus_id, v_debatle_bonus_votes_attribute_id, jsonb '-1', null);

      insert into data.objects(code, class_id) values ('debatle_bonus_asters_words', v_debatle_bonus_class_id) returning id into v_debatle_bonus_id;
    insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
    (v_debatle_bonus_id, v_title_attribute_id, jsonb '"использование астерского"', null),
    (v_debatle_bonus_id, v_debatle_bonus_votes_attribute_id, jsonb '1', null);

    insert into data.objects(code, class_id) values ('debatle_bonus_poems', v_debatle_bonus_class_id) returning id into v_debatle_bonus_id;
    insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
    (v_debatle_bonus_id, v_title_attribute_id, jsonb '"использование стихов"', null),
    (v_debatle_bonus_id, v_debatle_bonus_votes_attribute_id, jsonb '1', null);

    insert into data.objects(code, class_id) values ('debatle_bonus_rap', v_debatle_bonus_class_id) returning id into v_debatle_bonus_id;
    insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
    (v_debatle_bonus_id, v_title_attribute_id, jsonb '"использование рэпа"', null),
    (v_debatle_bonus_id, v_debatle_bonus_votes_attribute_id, jsonb '1', null);

    insert into data.objects(code, class_id) values ('debatle_bonus_support', v_debatle_bonus_class_id) returning id into v_debatle_bonus_id;
    insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
    (v_debatle_bonus_id, v_title_attribute_id, jsonb '"поддержку аудитории"', null),
    (v_debatle_bonus_id, v_debatle_bonus_votes_attribute_id, jsonb '1', null);

  end;

  insert into data.actions(code, function) values
  ('create_debatle_step1', 'pallas_project.act_create_debatle_step1'),
  ('debatle_change_person', 'pallas_project.act_debatle_change_person'),
  ('debatle_change_theme', 'pallas_project.act_debatle_change_theme'),
  ('debatle_change_status', 'pallas_project.act_debatle_change_status'),
  ('debatle_vote', 'pallas_project.act_debatle_vote'),
  ('debatle_change_bonuses','pallas_project.act_debatle_change_bonuses'),
  ('debatle_change_other_bonus','pallas_project.act_debatle_change_other_bonus');

end;
$$
language plpgsql;
