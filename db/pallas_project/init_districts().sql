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
  ('district_control', 'Контроль', 'Организация, контролирующая район', 'normal', null, 'pallas_project.vd_link', false),
  ('district_population', 'Население', 'Население района', 'normal', null, null, false);

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
            {"code": "group", "attributes": ["district_population", "district_control"]}
          ]
        }
      }
    ]');

  -- Районы
  for v_district in
  (
    select
      json.get_string(value, 'sector') sector,
      json.get_integer(value, 'population') population
    from jsonb_array_elements(
      jsonb '[
        {"sector": "A", "population": 22500},
        {"sector": "B", "population": 45000},
        {"sector": "C", "population": 67500},
        {"sector": "D", "population": 112500},
        {"sector": "E", "population": 225000},
        {"sector": "F", "population": 112500},
        {"sector": "G", "population": 225000}
      ]')
  )
  loop
    perform data.create_object(
      'sector_' || v_district.sector,
      format(
        '[
          {"code": "title", "value": "%s"},
          {"code": "district_population", "value": %s},
          {"code": "content", "value": []},
          {"code": "content", "value": [], "value_object_code": "master"}
        ]',
        'Сектор ' || v_district.sector,
        v_district.population)::jsonb,
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
