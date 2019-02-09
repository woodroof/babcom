-- drop function data.create_class(text, jsonb);

create or replace function data.create_class(in_code text, in_attributes jsonb)
returns integer
volatile
as
$$
-- У параметра in_changes есть два возможных формата:
-- 1. Объект, где ключ - код атрибута, а значение - значение атрибута
-- 2. Массив объектов с полями id или code, value_object_id, или value_object_code, value
declare
  v_attributes jsonb := data.preprocess_changes_with_codes(in_attributes);
  v_class_id integer;
  v_attribute record;
begin
  assert in_code is not null;

  insert into data.objects(code, type)
  values(in_code, 'class')
  returning id into v_class_id;

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
    values(v_class_id, v_attribute.id, v_attribute.value, v_attribute.value_object_id);
  end loop;

  return v_class_id;
end;
$$
language plpgsql;
