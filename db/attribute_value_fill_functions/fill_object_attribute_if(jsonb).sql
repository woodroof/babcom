-- Function: attribute_value_fill_functions.fill_object_attribute_if(jsonb)

-- DROP FUNCTION attribute_value_fill_functions.fill_object_attribute_if(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.fill_object_attribute_if(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_object_id integer := json.get_integer(in_params, 'object_id');

  v_conditions jsonb := json.get_object_array(in_params, 'conditions');
  v_condition jsonb;

  v_check_attribute_id integer;
  v_check_attribute_value jsonb;
  v_checked boolean;

  v_function text;
  v_params jsonb;
begin
  for v_condition in
    select value
    from jsonb_array_elements(v_conditions)
  loop
    v_check_attribute_id := data.get_attribute_id(json.get_string(v_condition, 'attribute_code'));
    v_check_attribute_value := v_condition->'attribute_value';

    select true
    into v_checked
    from data.attribute_values
    where
      object_id = v_object_id and
      attribute_id = v_check_attribute_id and
      value_object_id is null and
      value = v_check_attribute_value;

    if v_checked is not null then
      exit;
    end if;
  end loop;

  if v_checked is null then
    return;
  end if;

  v_function := json.get_string(in_params, 'function');
  v_params :=
    json.get_opt_object(in_params, jsonb '{}', 'params') ||
    jsonb_build_object(
      'user_object_id', json.get_integer(in_params, 'user_object_id'),
      'object_id', v_object_id,
      'attribute_id', json.get_integer(in_params, 'attribute_id'));
  execute format('select attribute_value_fill_functions.%s($1)', v_function)
  using v_params;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
