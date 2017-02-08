-- Function: attribute_value_change_functions.boolean_value_to_attribute(jsonb)

-- DROP FUNCTION attribute_value_change_functions.boolean_value_to_attribute(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_change_functions.boolean_value_to_attribute(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_value_object_id integer := json.get_opt_integer(in_params, null, 'value_object_id');
  v_old_value boolean := json.get_opt_boolean(in_params, null, 'old_value');
  v_new_value boolean := json.get_opt_boolean(in_params, null, 'new_value');
  v_dest_object_code text := json.get_string(in_params, 'object_code');
  v_dest_attribute_code text := json.get_string(in_params, 'attribute_code');
  v_dest_object_id integer;
  v_dest_attribute_id integer;
  v_dest_attribute_value jsonb;
begin
  if v_value_object_id is not null then
    return;
  end if;

  if coalesce(v_old_value, false) = coalesce(v_new_value, false) then
    return;
  end if;

  v_dest_object_id := data.get_object_id(v_dest_object_code);
  v_dest_attribute_id := data.get_attribute_id(v_dest_attribute_code);

  v_dest_attribute_value :=
    json.get_opt_array(
      data.get_attribute_value_for_update(
        v_dest_object_id,
        v_dest_attribute_id,
        null));

  if v_old_value is not null and v_old_value then
    v_dest_attribute_value := json.get_array(v_dest_attribute_value);
    v_dest_attribute_value := v_dest_attribute_value - data.get_object_code(v_object_id);
  elsif v_new_value is not null and v_new_value then
    v_dest_attribute_value := jsonb_build_array(data.get_object_code(v_object_id)) || coalesce(v_dest_attribute_value, jsonb '[]');
  end if;

  perform data.set_attribute_value(v_dest_object_id, v_dest_attribute_id, null, v_dest_attribute_value);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
