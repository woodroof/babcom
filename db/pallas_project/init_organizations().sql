-- drop function pallas_project.init_organizations();

create or replace function pallas_project.init_organizations()
returns void
volatile
as
$$
declare
  v_district record;
begin
  insert into data.params(code, value) values
  ('ice_prices', jsonb '{"org_aqua_galactic": 2, "org_jonny_quick": 1, "org_midnight_diggers": 1}'),
  ('foodstuff_prices', jsonb '{"org_alfa_prime": 2, "org_lenin_state_farm": 1, "org_ganymede_hydroponical_systems": 1}'),
  ('medical_supplies_prices', jsonb '{"org_merck": 2, "org_flora": 1, "org_vector": 1}'),
  ('uranium_prices', jsonb '{"org_westinghouse": 2, "org_trans_uranium": 1, "org_heavy_industries": 1}'),
  ('methane_prices', jsonb '{"org_comet_petroleum": 2, "org_stardust_industries": 1, "org_pdvsa": 1}'),
  ('goods_prices', jsonb '{"org_toom": 2, "org_amazon": 1, "org_big_warehouse": 1}');

  insert into data.actions(code, function) values
  ('change_next_tax', 'pallas_project.act_change_next_tax'),
  ('change_current_tax', 'pallas_project.act_change_current_tax'),
  ('change_next_budget', 'pallas_project.act_change_next_budget'),
  ('change_next_profit', 'pallas_project.act_change_next_profit'),
  ('transfer_org_money', 'pallas_project.act_transfer_org_money'),
  ('change_org_money', 'pallas_project.act_change_org_money'),
  ('act_buy_primary_resource', 'pallas_project.act_buy_primary_resource');

  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('system_org_synonym', null, 'Код оригинальной организации, string', 'system', null, null, false),
  ('org_synonym', 'Синоним', null, 'normal', 'full', 'pallas_project.vd_link', true),
  ('system_org_districts_control', null, 'Список кодов районов, которые контролирует организация', 'system', null, null, false),
  ('org_districts_control', 'Контроль', null, 'normal', 'full', 'pallas_project.vd_org_districts_control', true),
  ('system_org_districts_influence', null, 'Может ли организация контролировать районы, string', 'normal', null, null, false),
  ('org_districts_influence', 'Влияние', null, 'normal', 'full', 'pallas_project.vd_org_districts_influence', true),
  ('system_org_economics_type', null, 'Тип экономики (normal, budget, profit)', 'system', null, null, false),
  ('org_economics_type', 'Тип экономики', null, 'normal', 'full', 'pallas_project.vd_org_economics_type', true),
  ('system_org_budget', null, null, 'system', null, null, false),
  ('org_budget', 'Бюджет на следующий цикл', null, 'normal', 'full', 'pallas_project.vd_money', true),
  ('system_org_profit', null, null, 'system', null, null, false),
  ('org_profit', 'Поступления в следующем цикле', null, 'normal', 'full', 'pallas_project.vd_money', true),
  ('system_org_tax', null, null, 'system', null, null, false),
  ('org_tax', 'Текущая налоговая ставка', null, 'normal', 'full', 'pallas_project.vd_percent', true),
  ('system_org_next_tax', null, null, 'system', null, null, false),
  ('org_next_tax', 'Налоговая ставка на следующий цикл', null, 'normal', 'full', 'pallas_project.vd_percent', true),
  ('system_org_current_tax_sum', null, 'Накопленная сумма налогов за текущий цикл', 'system', null, null, false),
  ('org_current_tax_sum', 'Накопленная сумма налогов за текущий цикл', null, 'normal', 'full', 'pallas_project.vd_money', true),
  ('system_resource_ice', null, null, 'system', null, null, false),
  ('resource_ice', 'Лёд', null, 'normal', 'full', null, true),
  ('system_resource_foodstuff', null, null, 'system', null, null, false),
  ('resource_foodstuff', 'Продукты', null, 'normal', 'full', null, true),
  ('system_resource_medical_supplies', null, null, 'system', null, null, false),
  ('resource_medical_supplies', 'Медикаменты', null, 'normal', 'full', null, true),
  ('system_resource_uranium', null, null, 'system', null, null, false),
  ('resource_uranium', 'Уран', null, 'normal', 'full', null, true),
  ('system_resource_methane', null, null, 'system', null, null, false),
  ('resource_methane', 'Метан', null, 'normal', 'full', null, true),
  ('system_resource_goods', null, null, 'system', null, null, false),
  ('resource_goods', 'Товары', null, 'normal', 'full', null, true);

  perform data.create_class(
    'organization',
    jsonb '{
      "type": "organization",
      "is_visible": true,
      "actions_function": "pallas_project.actgenerator_organization",
      "template": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [
          {
            "code": "personal_info",
            "attributes": ["org_synonym", "org_economics_type", "money", "org_budget", "org_profit", "org_tax", "org_next_tax", "org_current_tax_sum", "org_districts_control", "org_districts_influence"],
            "actions": ["transfer_money", "transfer_org_money1", "transfer_org_money2", "transfer_org_money3", "transfer_org_money4", "transfer_org_money5", "change_org_money", "change_current_tax", "change_next_tax", "change_next_budget", "change_next_profit", "show_transactions", "show_contracts", "show_claims"]
          },
          {"code": "ice", "attributes": ["resource_ice"], "actions": ["buy_aqua_galactic", "buy_jonny_quick", "buy_midnight_diggers"]},
          {"code": "foodstuff", "attributes": ["resource_foodstuff"], "actions": ["buy_alfa_prime", "buy_lenin_state_farm", "buy_ganymede_hydroponical_systems"]},
          {"code": "medical_supplies", "attributes": ["resource_medical_supplies"], "actions": ["buy_merck", "buy_flora", "buy_vector"]},
          {"code": "uranium", "attributes": ["resource_uranium"], "actions": ["buy_westinghouse", "buy_trans_uranium", "buy_heavy_industries"]},
          {"code": "methane", "attributes": ["resource_methane"], "actions": ["buy_comet_petroleum", "buy_stardust_industries", "buy_pdvsa"]},
          {"code": "goods", "attributes": ["resource_goods"], "actions": ["buy_toom", "buy_amazon", "buy_big_warehouse"]},
          {"code": "info", "attributes": ["description"]}
        ]
      },
      "mini_card_template": {"title": "title", "subtitle": "subtitle", "groups": []}
    }');

  -- Организации
  perform pallas_project.create_organization(
    'org_administration',
    jsonb '{
      "title": "Администрация",
      "system_org_economics_type": "budget",
      "system_org_budget": 55000,
      "system_money": 55000,
      "system_org_tax": 25,
      "system_org_next_tax": 25,
      "system_org_current_tax_sum": 0,
      "system_resource_ice": 0,
      "system_resource_foodstuff": 0,
      "system_resource_medical_supplies": 0,
      "system_resource_uranium": 0,
      "system_resource_methane": 0,
      "system_resource_goods": 0
    }');
  perform pallas_project.create_organization(
    'org_opa',
    jsonb '{
      "title": "СВП",
      "system_org_economics_type": "normal",
      "system_money": 4000,
      "system_org_tax": 10,
      "system_org_next_tax": 10,
      "system_org_current_tax_sum": 0
    }');
  perform pallas_project.create_organization(
    'org_starbucks',
    jsonb '{
      "title": "Starbucks",
      "system_org_economics_type": "normal",
      "system_money": 2000,
      "system_org_tax": 20,
      "system_org_next_tax": 20,
      "system_org_current_tax_sum": 0
    }');

  perform pallas_project.create_organization(
    'org_de_beers',
    jsonb '{
      "title": "Де Бирс",
      "system_org_economics_type": "budget",
      "system_org_budget": 1380,
      "system_money": 1380
    }');
  perform pallas_project.create_organization(
    'org_akira_sc',
    jsonb '{
      "title": "Akira SC",
      "system_org_economics_type": "budget",
      "system_org_budget": 2000,
      "system_money": 2000
    }');
  perform pallas_project.create_organization(
    'org_clinic',
    jsonb '{
      "title": "Клиника",
      "system_org_economics_type": "budget",
      "system_org_budget": 250,
      "system_money": 250
    }');
  perform pallas_project.create_organization(
    'org_star_helix',
    jsonb '{
      "title": "Star Helix",
      "system_org_economics_type": "budget",
      "system_org_budget": 1300,
      "system_money": 1300
    }');

  perform pallas_project.create_organization(
    'org_teco_mars',
    jsonb '{
      "title": "Теко Марс",
      "system_org_economics_type": "profit",
      "system_org_profit": 1940,
      "system_money": 1940
    }');

  perform pallas_project.create_organization(
    'org_clean_asteroid',
    jsonb '{
      "title": "Чистый астероид",
      "subtitle": "Клининговая компания",
      "system_org_economics_type": "normal",
      "system_money": 0
    }');
  perform pallas_project.create_organization(
    'org_free_sky',
    jsonb '{
      "title": "Свободное небо",
      "system_org_economics_type": "normal",
      "system_money": 3500
    }');
  perform pallas_project.create_organization(
    'org_cherry_orchard',
    jsonb '{
      "title": "Вишнёвый сад",
      "system_org_economics_type": "normal",
      "system_money": 10000
    }');
  perform pallas_project.create_organization(
    'org_tariel',
    jsonb '{
      "title": "Тариэль",
      "subtitle": "Транспортная компания",
      "system_org_economics_type": "normal",
      "system_money": 1000
    }');
  perform pallas_project.create_organization(
    'org_tatu',
    jsonb '{
      "title": "Тату-салон",
      "system_org_economics_type": "profit",
      "system_org_profit": 120,
      "system_money": 120
    }');
  perform pallas_project.create_organization(
    'org_cavern',
    jsonb '{
      "title": "Каверна",
      "subtitle": "Бар",
      "system_org_economics_type": "profit",
      "system_org_profit": 500,
      "system_money": 500
    }');

  -- Мастерские компании
  perform pallas_project.create_organization(
    'org_riders_digest',
    jsonb '{
      "title": "Riders Digest",
      "subtitle": "Информационное агенство",
      "system_org_economics_type": "normal",
      "system_money": 50000
    }');
  perform pallas_project.create_organization(
    'org_white_star',
    jsonb '{
      "title": "White star",
      "subtitle": "IT-компания",
      "system_org_economics_type": "normal",
      "system_money": 0,
      "system_is_master_object": true
    }');

  -- Синонимы
  perform pallas_project.create_synonym(
    'org_starbucks',
    jsonb '{
      "title": "Третий глаз",
      "subtitle": "Салон"
    }');
  perform pallas_project.create_synonym(
    'org_white_star',
    jsonb '{
      "title": "Белый свет"
    }');
  perform pallas_project.create_synonym(
    'org_white_star',
    jsonb '{
      "title": "Сакура"
    }');
  perform pallas_project.create_synonym(
    'org_white_star',
    jsonb '{
      "title": "Сантьяго Де ла Круз компани"
    }');

  -- Синонимы-поставщики
  -- Лёд
  perform pallas_project.create_synonym(
    'org_aqua_galactic',
    'org_white_star',
    jsonb '{
      "title": "Аква Галактика"
    }');
  perform pallas_project.create_synonym(
    'org_jonny_quick',
    'org_free_sky',
    jsonb '{
      "title": "Джонни Квик"
    }');
  perform pallas_project.create_synonym(
    'org_midnight_diggers',
    'org_starbucks',
    jsonb '{
      "title": "Midnight Diggers"
    }');
  -- Продукты
  perform pallas_project.create_synonym(
    'org_alfa_prime',
    'org_white_star',
    jsonb '{
      "title": "Alfa Prime"
    }');
  perform pallas_project.create_synonym(
    'org_lenin_state_farm',
    'org_opa',
    jsonb '{
      "title": "Совхоз им. Ленина"
    }');
  perform pallas_project.create_synonym(
    'org_ganymede_hydroponical_systems',
    'org_starbucks',
    jsonb '{
      "title": "Гидропонические системы Ганимеда"
    }');
  -- Медикаменты
  perform pallas_project.create_synonym(
    'org_merck',
    'org_white_star',
    jsonb '{
      "title": "Merck"
    }');
  perform pallas_project.create_synonym(
    'org_flora',
    'org_opa',
    jsonb '{
      "title": "Флора Фармасьютикалс"
    }');
  perform pallas_project.create_synonym(
    'org_vector',
    'org_starbucks',
    jsonb '{
      "title": "Вектор"
    }');
  -- Уран
  perform pallas_project.create_synonym(
    'org_westinghouse',
    'org_white_star',
    jsonb '{
      "title": "Westinghouse"
    }');
  perform pallas_project.create_synonym(
    'org_trans_uranium',
    'org_opa',
    jsonb '{
      "title": "TransUranium"
    }');
  perform pallas_project.create_synonym(
    'org_heavy_industries',
    'org_free_sky',
    jsonb '{
      "title": "Heavy Industries Co."
    }');
  -- Метан
  perform pallas_project.create_synonym(
    'org_comet_petroleum',
    'org_white_star',
    jsonb '{
      "title": "Comet Petroleum"
    }');
  perform pallas_project.create_synonym(
    'org_stardust_industries',
    'org_opa',
    jsonb '{
      "title": "Stardust Industries"
    }');
  perform pallas_project.create_synonym(
    'org_pdvsa',
    'org_starbucks',
    jsonb '{
      "title": "PDVSA"
    }');
  -- Товары
  perform pallas_project.create_synonym(
    'org_toom',
    'org_white_star',
    jsonb '{
      "title": "Toom"
    }');
  perform pallas_project.create_synonym(
    'org_amazon',
    'org_opa',
    jsonb '{
      "title": "Amazon.com, Inc."
    }');
  perform pallas_project.create_synonym(
    'org_big_warehouse',
    'org_starbucks',
    jsonb '{
      "title": "Большой Склад"
    }');

  -- Создадим объект со списком организаций
  declare
    v_organization_list jsonb;
    v_class_id integer := data.get_class_id('organization');
  begin
    select jsonb_agg(o.code order by data.get_raw_attribute_value(o.code, 'title'))
    into v_organization_list
    from data.objects o
    where o.class_id = v_class_id;

    perform data.create_object(
      'organizations',
      format(
        '{
          "type": "organization_list",
          "is_visible": true,
          "title": "Все организации",
          "content": %s,
          "template": {
            "title": "title",
            "groups": []
          }
        }',
        v_organization_list::text)::jsonb);
  end;
end;
$$
language plpgsql;
