-- drop function pallas_project.init_persons();

create or replace function pallas_project.init_persons()
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
  v_mini_card_function_attribute_id integer := data.get_attribute_id('mini_card_function');
  v_actions_function_attribute_id integer := data.get_attribute_id('actions_function');
  v_template_attribute_id integer := data.get_attribute_id('template');

  v_description_attribute_id integer;
  v_person_state_attribute_id integer;
  v_person_occupation_attribute_id integer; 
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
  v_mcr_group_id integer;
  v_opa_group_id integer;
  v_master_group_id integer;
  v_player_group_id integer;

  v_login_id integer;
  v_person_id integer;
  v_person_class_id integer;
begin
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden)
  values ('person_occupation', null, 'Должность', 'normal', null, null, true)
  returning id into v_person_occupation_attribute_id;

  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden)
  values ('person_state', null, 'Гражданство', 'normal', 'full', 'pallas_project.vd_person_state', true)
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

  --Объект класса для персон
  insert into data.objects(code, type) values('person', 'class') returning id into v_person_class_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_class_id, v_type_attribute_id, jsonb '"person"'),
  (v_person_class_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_person_class_id, v_priority_attribute_id, jsonb '200'),
  (v_person_class_id, v_full_card_function_attribute_id, jsonb '"pallas_project.fcard_person"'),
  (v_person_class_id, v_mini_card_function_attribute_id, jsonb '"pallas_project.mcard_person"'),
  (v_person_class_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_person"'),
  (v_person_class_id, v_template_attribute_id, jsonb_build_object('groups', array[format(
                                                      '{"code": "%s", "attributes": ["%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s"]}',
                                                      'person_group1',
                                                      'person_state',
                                                      'person_occupation',
                                                      'money',
                                                      'person_deposit_money',
                                                      'person_coin',
                                                      'person_opa_rating',
                                                      'person_un_rating',
                                                      'description')::jsonb]));

  -- Группы персон
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

-- Мастера:
  insert into data.objects(class_id) values(v_person_class_id) returning id into v_person_id;
  insert into data.logins(code) values('m1') returning id into v_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_login_id, v_person_id);
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_id, v_title_attribute_id, jsonb '"Саша"'),
  (v_person_id, v_person_occupation_attribute_id, jsonb '"Мастер"');
  perform data.add_object_to_object(v_person_id, v_master_group_id);

  insert into data.objects(class_id) values(v_person_class_id) returning id into v_person_id;
  insert into data.logins(code) values('m2') returning id into v_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_login_id, v_person_id);
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_id, v_title_attribute_id, jsonb '"Пётр"'),
  (v_person_id, v_person_occupation_attribute_id, jsonb '"Мастер"');
  perform data.add_object_to_object(v_person_id, v_master_group_id);

  insert into data.objects(class_id) values(v_person_class_id) returning id into v_person_id;
  insert into data.logins(code) values('m3') returning id into v_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_login_id, v_person_id);
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_id, v_title_attribute_id, jsonb '"Данил"'),
  (v_person_id, v_person_occupation_attribute_id, jsonb '"Мастер"');
  perform data.add_object_to_object(v_person_id, v_master_group_id);

-- Игроки:
  insert into data.objects(class_id) values(v_person_class_id) returning id into v_person_id;
  insert into data.logins(code) values('p1') returning id into v_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_login_id, v_person_id);
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_id, v_title_attribute_id, jsonb '"Джерри Адамс"'),
  (v_person_id, v_person_state_attribute_id, jsonb '"un"'),
  (v_person_id, v_person_occupation_attribute_id, jsonb '"Секретарь администрации"'),
  (v_person_id, v_system_money_attribute_id, jsonb '0'),
  (v_person_id, v_system_person_coin_attribute_id, jsonb '50'),
  (v_person_id, v_system_person_opa_rating_attribute_id, jsonb '1'),
  (v_person_id, v_system_person_un_rating_attribute_id, jsonb '150');
  perform data.add_object_to_object(v_person_id, v_all_person_group_id);
  perform data.add_object_to_object(v_person_id, v_un_group_id);
  perform data.add_object_to_object(v_person_id, v_player_group_id);

  insert into data.objects(class_id) values(v_person_class_id) returning id into v_person_id;
  insert into data.logins(code) values('p2') returning id into v_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_login_id, v_person_id);
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_id, v_title_attribute_id, jsonb '"Сьюзан Сидорова"'),
  (v_person_id, v_person_state_attribute_id, jsonb '"aster"'),
  (v_person_id, v_person_occupation_attribute_id, jsonb '"Шахтёр"'),
  (v_person_id, v_system_money_attribute_id, jsonb '65000'),
  (v_person_id, v_system_person_opa_rating_attribute_id, jsonb '5'),
  (v_person_id, v_system_person_un_rating_attribute_id, jsonb '0');
  perform data.add_object_to_object(v_person_id, v_all_person_group_id);
  perform data.add_object_to_object(v_person_id, v_opa_group_id);
  perform data.add_object_to_object(v_person_id, v_player_group_id);
  perform data.add_object_to_object(v_person_id, v_aster_group_id);

  insert into data.objects(class_id) values(v_person_class_id) returning id into v_person_id;
  insert into data.logins(code) values('p3') returning id into v_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_login_id, v_person_id);
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_id, v_title_attribute_id, jsonb '"Чарли Чандрасекар"'),
  (v_person_id, v_person_state_attribute_id, jsonb '"un"'),
  (v_person_id, v_person_occupation_attribute_id, jsonb '"Главный экономист"'),
  (v_person_id, v_system_person_coin_attribute_id, jsonb '50'),
  (v_person_id, v_system_person_opa_rating_attribute_id, jsonb '1'),
  (v_person_id, v_system_person_un_rating_attribute_id, jsonb '200');
  perform data.add_object_to_object(v_person_id, v_all_person_group_id);
  perform data.add_object_to_object(v_person_id, v_player_group_id);
  perform data.add_object_to_object(v_person_id, v_un_group_id);
end;
$$
language plpgsql;
