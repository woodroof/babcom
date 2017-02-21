-- Function: action_generators.generate_if_attribute_for_user(jsonb)

-- DROP FUNCTION action_generators.generate_if_attribute_for_user(jsonb);

CREATE OR REPLACE FUNCTION action_generators.generate_if_attribute_for_user(in_params jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_object_id integer := json.get_opt_integer(in_params, null, 'object_id');

  v_user_object_id integer;

  v_check_attribute_id integer;
  v_check_attribute_value jsonb;
  v_current_value jsonb;

  v_function text;
  v_params jsonb;
  v_ret_val jsonb;
begin
  if v_object_id is null then
    return null;
  end if;

  v_user_object_id := json.get_integer(in_params, 'user_object_id');
  v_check_attribute_id := data.get_attribute_id(json.get_string(in_params, 'attribute_code'));
  v_check_attribute_value := in_params->'attribute_value';

  v_current_value := data.get_attribute_value(v_user_object_id, v_object_id, v_check_attribute_id);
  if v_current_value is null or v_current_value != v_check_attribute_value then
    return null;
  end if;

  v_function := json.get_string(in_params, 'function');
  v_params :=
    json.get_opt_object(in_params, jsonb '{}', 'params') ||
    jsonb_build_object(
      'user_object_id', v_user_object_id,
      'object_id', v_object_id);

  execute format('select action_generators.%s($1)', v_function)
  using v_params
  into v_ret_val;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
