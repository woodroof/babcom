-- Function: data.get_attribute_values_descriptions(integer, integer[], jsonb[], text[])

-- DROP FUNCTION data.get_attribute_values_descriptions(integer, integer[], jsonb[], text[]);

CREATE OR REPLACE FUNCTION data.get_attribute_values_descriptions(
    in_user_object_id integer,
    in_attribute_ids integer[],
    in_values jsonb[],
    in_functions text[])
  RETURNS text AS
$BODY$
declare
  v_ret_val text[];
  v_next_val text;
begin
  assert in_user_object_id is not null;
  assert in_attribute_ids is not null;
  assert array_length(in_attribute_ids, 1) = array_length(in_values, 1);
  assert array_length(in_attribute_ids, 1) = array_length(in_functions, 1);

  for i in 1..array_length(in_attribute_ids, 1) loop
    assert in_attribute_ids[i] is not null;

    if in_functions[i] is not null and in_values[i] is not null then
      execute 'select attribute_value_description_functions.' || in_functions[i] || '($1, $2, $3)'
      using in_user_object_id, in_attribute_ids[i], in_values[i]
      into v_next_val;

      v_ret_val := v_ret_val || v_next_val;
    else
      v_ret_val := v_ret_val || null::text;
    end if;
  end loop;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
