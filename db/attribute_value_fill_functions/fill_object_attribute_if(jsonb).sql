-- Function: attribute_value_fill_functions.fill_object_attribute_if(jsonb)

-- DROP FUNCTION attribute_value_fill_functions.fill_object_attribute_if(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.fill_object_attribute_if(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_object_id integer := json.get_integer(in_params, 'object_id');

  v_check_attribute_id integer := data.get_attribute_id(json.get_string(in_params, 'attribute_code'));
  v_check_attribute_value jsonb := in_params->'attribute_value';
  v_condition boolean := false;

  v_function text;
  v_params jsonb;
begin
  select true
  into v_condition
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_check_attribute_id and
    value_object_id is null and
    value = v_check_attribute_value;

  if not v_condition then
    return;
  end if;

  v_function := json.get_string(in_params, 'function');
  v_params :=
    json.get_opt_object(in_params, jsonb '{}', 'params') ||
    jsonb_build_object(
      'object_id', v_object_id,
      'attribute_id', json.get_integer(in_params, 'attribute_id'));
  execute format('select attribute_value_fill_functions.%s($1)', v_function)
  using v_params;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
