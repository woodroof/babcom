-- drop function pallas_project.init_districts();

create or replace function pallas_project.init_districts()
returns void
volatile
as
$$
begin
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('district_control', 'Контроль', null, 'normal', null, 'pallas_project.vd_district_control', false),
  ('district_population', 'Население', null, 'normal', null, null, false),
  ('district_influence', 'Влияние', null, 'normal', null, 'pallas_project.vd_district_influence', false),
  ('district_tax', 'Налоговая ставка', null, 'normal', null, 'pallas_project.vd_percent', false),
  ('system_district_tax_coeff', null, 'Коэффициент, на который умножаются налоговые поступления', 'system', null, null, false),
  ('system_district_resources', null, null, 'system', null, null, false);

  insert into data.actions(code, function) values
  ('district_change_control', 'pallas_project.act_district_change_control'),
  ('district_remove_control', 'pallas_project.act_district_remove_control'),
  ('district_change_influence', 'pallas_project.act_district_change_influence');

  -- Класс района
  perform data.create_class(
    'district',
    jsonb '[
      {"code": "is_visible", "value": true},
      {"code": "type", "value": "district"},
      {"code": "actions_function", "value": "pallas_project.actgenerator_district"},
      {"code": "independent_from_actor_list_elements", "value": true},
      {"code": "independent_from_object_list_elements", "value": true},
      {
        "code": "template",
        "value": {
          "title": "title",
          "groups": [
            {
              "code": "group",
              "attributes": ["district_tax", "district_control", "district_influence", "district_population"],
              "actions": ["change_administration_influence", "change_cartel_influence", "change_opa_influence", "set_administration_control", "set_cartel_control", "set_opa_control", "remove_control"]
            }
          ]
        }
      }
    ]');

  -- Районы
  perform data.create_object(
    'sector_A',
    jsonb '[
      {"code": "title", "value": "Сектор A"},
      {"code": "system_district_tax_coeff", "value": 2.5},
      {"code": "district_population", "value": 22500},
      {"code": "district_tax", "value": 25},
      {"code": "district_influence", "value": {"opa": 0, "cartel": 0, "administration": 1}},
      {"code": "district_control", "value": "administration"},
      {"code": "content", "value": []},
      {"code": "content", "value": [], "value_object_code": "master"},
      {"code": "system_district_resources", "value": {"water": 202.5, "food": 202.5, "medicine": 202.5, "power": 202.5}}
    ]',
    'district');
  perform data.create_object(
    'sector_B',
    jsonb '[
      {"code": "title", "value": "Сектор B"},
      {"code": "system_district_tax_coeff", "value": 5},
      {"code": "district_population", "value": 45000},
      {"code": "district_tax", "value": 25},
      {"code": "district_influence", "value": {"opa": 0, "cartel": 0, "administration": 1}},
      {"code": "district_control", "value": "administration"},
      {"code": "content", "value": []},
      {"code": "content", "value": [], "value_object_code": "master"},
      {"code": "system_district_resources", "value": {"water": 405, "food": 405, "medicine": 405, "power": 405}}
    ]',
    'district');
  perform data.create_object(
    'sector_C',
    jsonb '[
      {"code": "title", "value": "Сектор C"},
      {"code": "system_district_tax_coeff", "value": 7.5},
      {"code": "district_population", "value": 67500},
      {"code": "district_tax", "value": 25},
      {"code": "district_influence", "value": {"opa": 0, "cartel": 0, "administration": 1}},
      {"code": "district_control", "value": "administration"},
      {"code": "content", "value": []},
      {"code": "content", "value": [], "value_object_code": "master"},
      {"code": "system_district_resources", "value": {"water": 405, "food": 405, "medicine": 405, "power": 405}}
    ]',
    'district');
  perform data.create_object(
    'sector_D',
    jsonb '[
      {"code": "title", "value": "Сектор D"},
      {"code": "system_district_tax_coeff", "value": 12.5},
      {"code": "district_population", "value": 112500},
      {"code": "district_tax", "value": 10},
      {"code": "district_influence", "value": {"opa": 1, "cartel": 0, "administration": 0}},
      {"code": "district_control", "value": "opa"},
      {"code": "content", "value": []},
      {"code": "content", "value": [], "value_object_code": "master"},
      {"code": "system_district_resources", "value": {"water": 675, "food": 675, "medicine": 675, "power": 675}}
    ]',
    'district');
  perform data.create_object(
    'sector_E',
    jsonb '[
      {"code": "title", "value": "Сектор E"},
      {"code": "system_district_tax_coeff", "value": 25},
      {"code": "district_population", "value": 225000},
      {"code": "district_tax", "value": 0},
      {"code": "district_influence", "value": {"opa": 0, "cartel": 0, "administration": 0}},
      {"code": "district_control", "value": null},
      {"code": "content", "value": []},
      {"code": "content", "value": [], "value_object_code": "master"},
      {"code": "system_district_resources", "value": {"water": 1350, "food": 1350, "medicine": 1350, "power": 1350}}
    ]',
    'district');
  perform data.create_object(
    'sector_F',
    jsonb '[
      {"code": "title", "value": "Сектор F"},
      {"code": "system_district_tax_coeff", "value": 12.5},
      {"code": "district_population", "value": 112500},
      {"code": "district_tax", "value": 10},
      {"code": "district_influence", "value": {"opa": 1, "cartel": 0, "administration": 0}},
      {"code": "district_control", "value": "opa"},
      {"code": "content", "value": []},
      {"code": "content", "value": [], "value_object_code": "master"},
      {"code": "system_district_resources", "value": {"water": 337.5, "food": 337.5, "medicine": 337.5, "power": 337.5}}
    ]',
    'district');
  perform data.create_object(
    'sector_G',
    jsonb '[
      {"code": "title", "value": "Сектор G"},
      {"code": "system_district_tax_coeff", "value": 25},
      {"code": "district_population", "value": 225000},
      {"code": "district_tax", "value": 20},
      {"code": "district_influence", "value": {"opa": 0, "cartel": 1, "administration": 0}},
      {"code": "district_control", "value": "cartel"},
      {"code": "content", "value": []},
      {"code": "content", "value": [], "value_object_code": "master"},
      {"code": "system_district_resources", "value": {"water": 675, "food": 675, "medicine": 675, "power": 675}}
    ]',
    'district');

  -- Список районов
  perform data.create_object(
    'districts',
    jsonb '[
      {"code": "type", "value": "districts"},
      {"code": "is_visible", "value": true},
      {"code": "title", "value": "Районы"},
      {"code": "independent_from_actor_list_elements", "value": true},
      {"code": "independent_from_object_list_elements", "value": true},
      {
        "code": "template",
        "value": {
          "title": "title",
          "groups": []
        }
      },
      {
        "code": "content",
        "value": ["sector_A", "sector_B", "sector_C", "sector_D", "sector_E", "sector_F", "sector_G"]
      }
    ]');
end;
$$
language plpgsql;
