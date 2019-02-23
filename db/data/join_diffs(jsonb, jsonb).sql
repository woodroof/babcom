-- drop function data.join_diffs(jsonb, jsonb);

create or replace function data.join_diffs(in_diffs1 jsonb, in_diffs2 jsonb)
returns jsonb
immutable
as
$$
-- Функция пока не поддерживает объединение diff'ов с изменениями списков
declare
  v_diffs1_object jsonb;
  v_diffs2_object jsonb;
  v_ret_val jsonb;
begin
  select jsonb_object_agg(json.get_string(value, 'object_id') || '#' || json.get_integer(value, 'client_id'), value)
  into v_diffs1_object
  from jsonb_array_elements(in_diffs1);

  select jsonb_object_agg(json.get_string(value, 'object_id') || '#' || json.get_integer(value, 'client_id'), value)
  into v_diffs2_object
  from jsonb_array_elements(in_diffs2);

  select jsonb_agg(value)
  into v_ret_val
  from jsonb_each(coalesce(v_diffs1_object, jsonb '{}') || coalesce(v_diffs2_object, jsonb '{}'));

  return coalesce(v_ret_val, jsonb '[]');
end;
$$
language plpgsql;
