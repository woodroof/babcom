-- Function: attribute_value_change_functions.string_value_to_attribute(jsonb)

-- DROP FUNCTION attribute_value_change_functions.string_value_to_attribute(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_change_functions.string_value_to_attribute(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_value_object_id integer := json.get_opt_integer(in_params, null, 'value_object_id');
  v_old_value text := json.get_opt_string(in_params, null, 'old_value');
  v_new_value text := json.get_opt_string(in_params, null, 'new_value');
  v_value_to_code_map jsonb := json.get_object(in_params, 'params');
  v_map_entry jsonb;
  v_old_object_code text;
  v_old_attribute_code text;
  v_new_object_code text;
  v_new_attribute_code text;

  v_object_code text;
  v_user_object_id integer;

  v_modified_object_id integer;
  v_modified_attribute_id integer;
  v_modified_attribute_value jsonb;
begin
  if v_value_object_id is not null then
    return;
  end if;

  if v_old_value is not null then
    v_map_entry := json.get_opt_object(v_value_to_code_map, null, v_old_value);
    if v_map_entry is not null then
      v_old_object_code := json.get_string(v_map_entry, 'object_code');
      v_old_attribute_code := json.get_string(v_map_entry, 'attribute_code');
    end if;
  end if;
  if v_new_value is not null then
    v_map_entry := json.get_opt_object(v_value_to_code_map, null, v_new_value);
    if v_map_entry is not null then
      v_new_object_code := json.get_string(v_map_entry, 'object_code');
      v_new_attribute_code := json.get_string(v_map_entry, 'attribute_code');
    end if;
  end if;

  if
    v_old_object_code is null and v_new_object_code is null or
    v_old_object_code is not null and v_new_object_code is not null and v_old_object_code = v_new_object_code and v_old_attribute_code = v_new_attribute_code
  then
    return;
  end if;

  v_object_code := data.get_object_code(v_object_id);
  v_user_object_id := json.get_opt_integer(in_params, null, 'user_object_id');

  if v_old_object_code is not null then
    v_modified_object_id := data.get_object_id(v_old_object_code);
    v_modified_attribute_id := data.get_attribute_id(v_old_attribute_code);
    v_modified_attribute_value :=
      json.get_array(
        data.get_attribute_value_for_update(
          v_modified_object_id,
          v_modified_attribute_id,
          null));
    v_modified_attribute_value := v_modified_attribute_value - v_object_code;
    perform data.set_attribute_value(v_modified_object_id, v_modified_attribute_id, null, v_modified_attribute_value, v_user_object_id);
  end if;

  if v_new_object_code is not null then
    v_modified_object_id := data.get_object_id(v_new_object_code);
    v_modified_attribute_id := data.get_attribute_id(v_new_attribute_code);
    v_modified_attribute_value :=
      json.get_opt_array(
        data.get_attribute_value_for_update(
          v_modified_object_id,
          v_modified_attribute_id,
          null));
    v_modified_attribute_value := coalesce(v_modified_attribute_value, jsonb '[]') || jsonb_build_array(v_object_code);
    perform data.set_attribute_value(v_modified_object_id, v_modified_attribute_id, null, v_modified_attribute_value, v_user_object_id);
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
