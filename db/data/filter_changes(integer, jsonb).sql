-- drop function data.filter_changes(integer, jsonb);

create or replace function data.filter_changes(in_object_id integer, in_changes jsonb)
returns jsonb
volatile
as
$$
declare
  v_change record;
  v_filtered_changes jsonb := jsonb '[]';
  v_value jsonb;
  v_next_change jsonb;
begin
  assert data.is_instance(in_object_id);
  perform json.get_object_array(in_changes);

  for v_change in
  (
    select
      json.get_integer(value, 'id') as id,
      json.get_integer_opt(value, 'value_object_id', null) as value_object_id,
      value->'value' as value
    from jsonb_array_elements(in_changes)
  )
  loop
    v_value := data.get_raw_attribute_value(in_object_id, v_change.id, v_change.value_object_id);

    if
      -- Удалять нечего
      v_change.value is null and v_value is null or
      -- Уже то же значение
      v_change.value = v_value
    then
      continue;
    end if;

    v_next_change := jsonb_build_object('id', v_change.id);
    if v_change.value_object_id is not null then
      v_next_change := v_next_change || jsonb_build_object('value_object_id', v_change.value_object_id);
    end if;
    if v_change.value is not null then
      v_next_change := v_next_change || jsonb_build_object('value', v_change.value);
    end if;

    v_filtered_changes := v_filtered_changes || v_next_change;
  end loop;

  return v_filtered_changes;
end;
$$
language plpgsql;
