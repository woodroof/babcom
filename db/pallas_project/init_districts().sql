-- drop function pallas_project.init_districts();

create or replace function pallas_project.init_districts()
returns void
volatile
as
$$
declare
  v_districts jsonb := '[]';
  v_district record;
begin
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('district_control', 'Контроль', null, 'normal', null, 'pallas_project.vd_district_control', false),
  ('district_population', 'Население', null, 'normal', null, null, false),
  ('district_influence', 'Влияние', null, 'normal', null, 'pallas_project.vd_district_influence', false),
  ('district_tax', 'Налоговая ставка', null, 'normal', null, 'pallas_project.vd_percent', false);

  -- Класс района
  perform data.create_class(
    'district',
    jsonb '[
      {"code": "is_visible", "value": true},
      {"code": "type", "value": "district"},
      {
        "code": "template",
        "value": {
          "title": "title",
          "groups": [
            {"code": "group", "attributes": ["district_tax", "district_control", "district_influence", "district_population"]}
          ]
        }
      }
    ]');

  -- Районы
  for v_district in
  (
    select
      json.get_string(value, 'sector') sector,
      json.get_integer(value, 'population') population,
      json.get_integer(value, 'district_tax') tax,
      json.get_object(value, 'district_influence') influence,
      value->'district_control' control
    from jsonb_array_elements(
      jsonb '[
        {"sector": "A", "population": 22500, "district_tax": 25, "district_influence": {"opa": 0, "cartel": 0, "administration": 1}, "district_control": "administration"},
        {"sector": "B", "population": 45000, "district_tax": 25, "district_influence": {"opa": 0, "cartel": 0, "administration": 1}, "district_control": "administration"},
        {"sector": "C", "population": 67500, "district_tax": 25, "district_influence": {"opa": 0, "cartel": 0, "administration": 1}, "district_control": "administration"},
        {"sector": "D", "population": 112500, "district_tax": 10, "district_influence": {"opa": 1, "cartel": 0, "administration": 0}, "district_control": "opa"},
        {"sector": "E", "population": 225000, "district_tax": 0, "district_influence": {"opa": 0, "cartel": 0, "administration": 0}, "district_control": null},
        {"sector": "F", "population": 112500, "district_tax": 10, "district_influence": {"opa": 1, "cartel": 0, "administration": 0}, "district_control": "opa"},
        {"sector": "G", "population": 225000, "district_tax": 20, "district_influence": {"opa": 0, "cartel": 1, "administration": 0}, "district_control": "cartel"}
      ]')
  )
  loop
    perform data.create_object(
      'sector_' || v_district.sector,
      format(
        '[
          {"code": "title", "value": "%s"},
          {"code": "district_population", "value": %s},
          {"code": "district_tax", "value": %s},
          {"code": "district_influence", "value": %s},
          {"code": "district_control", "value": %s},
          {"code": "content", "value": []},
          {"code": "content", "value": [], "value_object_code": "master"}
        ]',
        'Сектор ' || v_district.sector,
        v_district.population,
        v_district.tax,
        v_district.influence::text,
        v_district.control::text)::jsonb,
      'district');

    v_districts := v_districts || to_jsonb('sector_' || v_district.sector);
  end loop;

  -- Список районов
  perform data.create_object(
    'districts',
    format(
      '[
        {"code": "type", "value": "districts"},
        {"code": "is_visible", "value": true},
        {"code": "title", "value": "Районы"},
        {
          "code": "template",
          "value": {
            "title": "title",
            "groups": []
          }
        },
        {
          "code": "content",
          "value": %s
        }
      ]',
      v_districts::text)::jsonb);
end;
$$
language plpgsql;
