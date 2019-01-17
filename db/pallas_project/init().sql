-- drop function pallas_project.init();

create or replace function pallas_project.init()
returns void
volatile
as
$$
declare
  v_type_attribute_id integer := data.get_attribute_id('type');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_subtitle_attribute_id integer := data.get_attribute_id('subtitle');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_priority_attribute_id integer := data.get_attribute_id('priority');
  v_full_card_function_attribute_id integer := data.get_attribute_id('full_card_function');
  v_actions_function_attribute_id integer := data.get_attribute_id('actions_function');

  v_description_attribute_id integer;
  v_person_state_attribute_id integer;
  v_system_money_attribute_id integer;
  v_money_attribute_id integer;
  v_system_person_deposit_money_attribute_id integer;
  v_person_deposit_money_attribute_id integer;
  v_system_person_coin_attribute_id integer;
  v_person_coin_attribute_id integer;
  v_system_person_opa_rating_attribute_id integer;
  v_person_opa_rating_attribute_id integer;
  v_system_person_un_rating_attribute_id integer;
  v_person_un_rating_attribute_id integer;
  v_person_is_master_attribute_id integer;

  v_all_person_group_id integer;
  v_aster_group_id integer;
  v_un_group_id integer;
  v_mars_group_id integer;
  v_opa_group_id integer;
  v_master_group_id integer;

  v_default_login_id integer;
  v_menu_id integer;
  v_notifications_id integer;
  v_test_id integer;
  v_person_id integer;

  v_template_groups jsonb[];
begin
  insert into data.attributes(code, description, type, card_type, can_be_overridden)
  values('description', 'Текстовый блок с развёрнутым описанием объекта, string', 'normal', 'full', true)
  returning id into v_description_attribute_id;

  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden)
  values ('person_state', null, 'Гражданство', 'normal', 'full', 'pallas_project.vd_person_state', false)
  returning id into v_person_state_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('system_money', 'Остаток средств на счёте', 'system', null, null, false)
  returning id into v_system_money_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('money', 'Остаток средств на счёте', 'normal', 'full', null, true)
  returning id into v_money_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('system_person_deposit_money', 'Остаток средств на накопительном счёте', 'system', null, null, false)
  returning id into v_system_person_deposit_money_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('person_deposit_money', 'Остаток средств на накопительном счёте', 'normal', 'full', null, true)
  returning id into v_person_deposit_money_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('system_person_coin', 'Остаток коинов', 'system', null, null, false)
  returning id into v_system_person_coin_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('person_coin', 'Остаток коинов', 'normal', 'full', null, true)
  returning id into v_person_coin_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('system_person_opa_rating', 'Рейтинг в СВП', 'system', null, null, false)
  returning id into v_system_person_opa_rating_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('person_opa_rating', 'Рейтинг в СВП', 'normal', 'full', null, true)
  returning id into v_person_opa_rating_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('system_person_un_rating', 'Рейтинг в ООН', 'system', null, null, false)
  returning id into v_system_person_un_rating_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('person_un_rating', 'Рейтинг в ООН', 'normal', 'full', null, true)
  returning id into v_person_un_rating_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('person_is_master', 'Признак мастерского персонажа', 'system', null, null, false)
  returning id into v_person_is_master_attribute_id;

  v_template_groups :=
    array_append(
      v_template_groups,
      format(
        '{"code": "%s", "attributes": ["%s"]}',
        'default_group1',
        'description')::jsonb);
  v_template_groups :=
    array_append(
      v_template_groups,
      format(
        '{"code": "%s", "actions": ["%s", "%s"]}',
        'menu_group1',
        'login',
        'debatles')::jsonb);
  v_template_groups :=
    array_append(
      v_template_groups,
      format(
        '{"code": "%s", "attributes": ["%s", "%s", "%s", "%s", "%s", "%s"]}',
        'person_group1',
        'person_state',
        'money',
        'person_deposit_money',
        'person_coin',
        'person_opa_rating',
        'person_un_rating')::jsonb);
  v_template_groups :=
    array_append(
      v_template_groups,
      format(
        '{"code": "%s", "attributes": ["%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s"]}',
        'debatle_group1',
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
        'debatle_person2_fines')::jsonb);


  -- Создадим актора по умолчанию, который является первым тестом
  insert into data.objects(code) values('test1') returning id into v_test_id;

  -- Логин по умолчанию
  insert into data.logins(code) values('default_login') returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_test_id);

 -- Первый персонаж:
  insert into data.objects(code) values('person1') returning id into v_person_id;
    -- Логин
  insert into data.logins(code) values('p1') returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_person_id);

  insert into data.params(code, value, description) values
  ('default_login_id', to_jsonb(v_default_login_id), 'Идентификатор логина по умолчанию'),
  (
    'template',
    jsonb_build_object('groups', to_jsonb(v_template_groups)),
    'Шаблон'
  );

  -- Также для работы нам понадобится объект меню
  insert into data.objects(code) values('menu') returning id into v_menu_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_menu_id, v_type_attribute_id, jsonb '"menu"'),
  (v_menu_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_menu_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_menu"');

  insert into data.actions(code, function) values
  ('act_open_object', 'pallas_project.act_open_object'),
  ('login', 'pallas_project.act_login');

  -- И пустой список уведомлений
  insert into data.objects(code) values('notifications') returning id into v_notifications_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_notifications_id, v_type_attribute_id, jsonb '"notifications"'),
  (v_notifications_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_notifications_id, v_content_attribute_id, jsonb '[]');

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text 'Добрый день!')
  );

  -- Группы персон
  insert into data.objects(code) values ('all_person') returning id into v_all_person_group_id;
  insert into data.objects(code) values ('aster') returning id into v_aster_group_id;
  insert into data.objects(code) values ('un') returning id into v_un_group_id;
  insert into data.objects(code) values ('mars') returning id into v_mars_group_id;
  insert into data.objects(code) values ('opa') returning id into v_opa_group_id;
  insert into data.objects(code) values ('master') returning id into v_master_group_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_all_person_group_id, v_priority_attribute_id, jsonb '10'),
  (v_aster_group_id, v_priority_attribute_id, jsonb '20'),
  (v_un_group_id, v_priority_attribute_id, jsonb '30'),
  (v_mars_group_id, v_priority_attribute_id, jsonb '40'),
  (v_opa_group_id, v_priority_attribute_id, jsonb '50'),
  (v_master_group_id, v_priority_attribute_id, jsonb '190');


  -- Данные персон
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_id, v_type_attribute_id, jsonb '"person"'),
  (v_person_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_person_id, v_title_attribute_id, jsonb '"Джерри Адамс"'),
  (v_person_id, v_priority_attribute_id, jsonb '200'),
  (v_person_id, v_person_state_attribute_id, jsonb '"un"'),
  (v_person_id, v_system_money_attribute_id, jsonb '0'),
  (v_person_id, v_system_person_coin_attribute_id, jsonb '50'),
  (v_person_id, v_system_person_opa_rating_attribute_id, jsonb '1'),
  (v_person_id, v_system_person_un_rating_attribute_id, jsonb '150'),
  (v_person_id, v_person_is_master_attribute_id, jsonb 'false'),
  (v_person_id, v_full_card_function_attribute_id, jsonb '"pallas_project.fcard_person"'),
  (v_person_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_menu"');

  insert into data.object_objects(parent_object_id, object_id) values
  (v_all_person_group_id, v_person_id),
  (v_un_group_id, v_person_id);

  perform pallas_project.init_debatles();
end;
$$
language 'plpgsql';
