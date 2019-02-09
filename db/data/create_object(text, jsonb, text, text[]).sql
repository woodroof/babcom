-- drop function data.create_object(text, jsonb, text, text[]);

create or replace function data.create_object(in_code text, in_attributes jsonb, in_class_code text default null::text, in_groups text[] default null::text[])
returns integer
volatile
as
$$
-- У параметра in_changes есть два возможных формата:
-- 1. Объект, где ключ - код атрибута, а значение - значение атрибута
-- 2. Массив объектов с полями id или code, value_object_id, или value_object_code, value
declare
  v_attributes jsonb;
  v_object_id integer;
  v_attribute record;
  v_group_code text;
begin
  if in_code is null then
    insert into data.objects(class_id)
    values(case when in_class_code is not null then data.get_class_id(in_class_code) else null end)
    returning id into v_object_id;
  else
    insert into data.objects(code, class_id)
    values(in_code, case when in_class_code is not null then data.get_class_id(in_class_code) else null end)
    returning id into v_object_id;
  end if;

  v_attributes := data.preprocess_changes_with_codes(in_attributes);

  for v_attribute in
  (
    select
      json.get_integer(value, 'id') id,
      json.get_integer_opt(value, 'value_object_id', null) value_object_id,
      value->'value' as value
    from jsonb_array_elements(v_attributes)
  )
  loop
    insert into data.attribute_values(object_id, attribute_id, value, value_object_id)
    values(v_object_id, v_attribute.id, v_attribute.value, v_attribute.value_object_id);
  end loop;

  for v_group_code in
  (
    select value
    from unnest(in_groups) a(value)
  )
  loop
    perform data.add_object_to_object(v_object_id, data.get_object_id(v_group_code));
  end loop;

  return v_object_id;
end;
$$
language plpgsql;
