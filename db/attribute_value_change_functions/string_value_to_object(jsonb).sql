-- Function: attribute_value_change_functions.string_value_to_object(jsonb)

-- DROP FUNCTION attribute_value_change_functions.string_value_to_object(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_change_functions.string_value_to_object(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_value_object_id integer := json.get_opt_integer(in_params, null, 'value_object_id');
  v_old_value text := json.get_opt_string(in_params, null, 'old_value');
  v_new_value text := json.get_opt_string(in_params, null, 'new_value');
  v_value_to_code_map jsonb := json.get_object(in_params, 'params');
  v_old_object_code text;
  v_new_object_code text;
begin
  if v_value_object_id is not null then
    return;
  end if;

  if v_old_value is not null then
    v_old_object_code := json.get_opt_string(v_value_to_code_map, null, v_old_value);
  end if;
  if v_new_value is not null then
    v_new_object_code := json.get_opt_string(v_value_to_code_map, null, v_new_value);
  end if;

  if
    v_old_object_code is not null and
    (
      v_new_object_code is null or
      v_old_object_code != v_new_object_code
    )
  then
    perform data.remove_object_from_object(
      v_object_id,
      data.get_object_id(v_old_object_code));
  end if;

  if
    v_new_object_code is not null and
    (
      v_old_object_code is null or
      v_old_object_code != v_new_object_code
    )
  then
    perform data.add_object_to_object(
      v_object_id,
      data.get_object_id(v_new_object_code));
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
