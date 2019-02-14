-- drop function pallas_project.init_districts();

create or replace function pallas_project.init_districts()
returns void
volatile
as
$$
declare
  v_districts jsonb := '[]';
  v_district text;
begin
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('district_control', 'Контроль', 'Организация, контролирующая район', 'normal', null, 'pallas_project.vd_link', false);

  -- Класс района
  perform data.create_class(
    'district',
    jsonb '[
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {"code": "type", "value": "district"},
      {
        "code": "template",
        "value": {
          "title": "title",
          "groups": [
            {"code": "group", "attributes": ["district_control"]}
          ]
        }
      }
    ]');

  -- Районы
  for v_district in
  (
    select value
    from unnest(array['A1', 'A2', 'B', 'C', 'D']) a(value)
  )
  loop
    declare
      v_district_id integer :=
        data.create_object(
          'district_' || v_district,
          format(
            '{
              "title": "%s"
            }',
            'Сектор ' || v_district)::jsonb,
          'district');
    begin
      v_districts := v_districts || to_jsonb(data.get_object_code(v_district_id));
    end;
  end loop;

  -- Список районов
  perform data.create_object(
    'districts',
    format(
      '[
        {"code": "type", "value": "districts"},
        {"code": "is_visible", "value": true, "value_object_code": "master"},
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
