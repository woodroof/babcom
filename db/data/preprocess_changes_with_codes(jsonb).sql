-- drop function data.preprocess_changes_with_codes(jsonb);

create or replace function data.preprocess_changes_with_codes(in_changes jsonb)
returns jsonb
stable
as
$$
-- У параметра in_changes есть два возможных формата:
-- 1. Только для установки значения: объект, где ключ - код атрибута, а значение - значение атрибута
-- 2. Массив объектов с полями id или code, value_object_id, или value_object_code, value

-- Возвращается массив объектов с полями id, value_object_id, value
declare
  v_change record;
  v_elem jsonb;
  v_ret_val jsonb := '[]';
begin
  if in_changes is null or in_changes = jsonb 'null' then
    return v_ret_val;
  end if;

  if jsonb_typeof(in_changes) = 'object' then
    for v_change in
    (
      select key, value
      from jsonb_each(in_changes)
    )
    loop
      v_ret_val := v_ret_val || jsonb_build_object('id', data.get_attribute_id(v_change.key), 'value', v_change.value);
    end loop;
  else
    for v_change in
    (
      select
        json.get_integer_opt(value, 'id', null) id,
        json.get_string_opt(value, 'code', null) code,
        json.get_integer_opt(value, 'value_object_id', null) value_object_id,
        json.get_string_opt(value, 'value_object_code', null) value_object_code,
        value->'value' as value
      from jsonb_array_elements(in_changes)
    )
    loop
      v_elem := '{}';

      if v_change.id is not null then
        assert v_change.code is null;

        v_elem := v_elem || jsonb_build_object('id', v_change.id);
      else
        assert v_change.code is not null;

        v_elem := v_elem || jsonb_build_object('id', data.get_attribute_id(v_change.code));
      end if;

      if v_change.value_object_id is not null then
        assert v_change.value_object_code is null;

        v_elem := v_elem || jsonb_build_object('value_object_id', v_change.value_object_id);
      elsif v_change.value_object_code is not null then
        v_elem := v_elem || jsonb_build_object('value_object_id', data.get_object_id(v_change.value_object_code));
      end if;

      if v_change.value is not null then
        v_elem := v_elem || jsonb_build_object('value', v_change.value);
      end if;

      v_ret_val := v_ret_val || v_elem;
    end loop;
  end if;

  return v_ret_val;
end;
$$
language plpgsql;
