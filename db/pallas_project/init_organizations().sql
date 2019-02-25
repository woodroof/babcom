-- drop function pallas_project.init_organizations();

create or replace function pallas_project.init_organizations()
returns void
volatile
as
$$
declare
  v_district record;
begin
  insert into data.actions(code, function) values
  ('change_next_tax', 'pallas_project.act_change_next_tax'),
  ('change_current_tax', 'pallas_project.act_change_current_tax'),
  ('transfer_org_money', 'pallas_project.act_transfer_org_money');

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
  ('org_current_tax_sum', 'Накопленная сумма налогов за текущий цикл', null, 'normal', 'full', 'pallas_project.vd_money', true);

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
            "actions": ["transfer_money", "transfer_org_money1", "transfer_org_money2", "transfer_org_money3", "transfer_org_money4", "transfer_org_money5", "change_current_tax", "change_next_tax", "show_transactions"]
          },
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
      "system_org_districts_control": ["sector_A", "sector_B", "sector_C"],
      "system_org_districts_influence": {"sector_A": 1, "sector_B": 1, "sector_C": 1, "sector_D": 0, "sector_E": 0, "sector_F": 0, "sector_G": 0},
      "system_org_economics_type": "budget",
      "system_org_budget": 55000,
      "system_money": 55000,
      "system_org_tax": 25,
      "system_org_next_tax": 25,
      "system_org_current_tax_sum": 0
    }');
  perform pallas_project.create_organization(
    'org_opa',
    jsonb '{
      "title": "СВП",
      "system_org_districts_control": ["sector_D", "sector_F"],
      "system_org_districts_influence": {"sector_A": 0, "sector_B": 0, "sector_C": 0, "sector_D": 1, "sector_E": 0, "sector_F": 1, "sector_G": 0},
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
      "system_org_districts_control": ["sector_G"],
      "system_org_districts_influence": {"sector_A": 0, "sector_B": 0, "sector_C": 0, "sector_D": 0, "sector_E": 0, "sector_F": 0, "sector_G": 1},
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

  -- Мастерская компания
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
    'org_opa',
    jsonb '{
      "title": "Тату-салон"
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

  -- Лёд: org_aqua_galactic, org_jonny_quick, org_midnight_diggers
  -- Продукты: org_alfa_prime, org_lenin_state_farm, org_ganymede_hydroponical_systems
  -- Медикаменты: org_merck, org_flora, org_vector
  -- Уран: org_westinghouse, org_trans_uranium, org_heavy_industries
  -- Метан: org_comet_petroleum, org_stardust_industries, org_pdvsa
  -- Товары: org_toom, org_amazon, org_big_warehouse

  -- Люди:
  --  org_administration: экономист - Александра Корсак, руководитель - Фрида Фогель
  --  org_opa: Роберт Ли, Лаура Джаррет и Люк Ламбер
  --  org_starbucks: Марк Попов
  --  org_de_beers: Мишон Грей и Абрахам Грей
  --  org_akira_sc: Марк Попов и Роберт Ли
  --  org_clinic: Лина Ковач
  --  org_star_helix: Кайла Ангас
  --  org_teco_mars: Рашид Файзи
  --  org_clean_asteroid: Янг
  --  org_free_sky: мормон
  --  org_cherry_orchard: Александра Корсак
  --  org_tariel: Валентин Штерн

  -- Прочие люди:
  --  Сантьяго Де ла Круз (головной картель)
end;
$$
language plpgsql;
