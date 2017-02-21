-- Function: action_generators.generate_if_any_user_attribute(jsonb)

-- DROP FUNCTION action_generators.generate_if_any_user_attribute(jsonb);

CREATE OR REPLACE FUNCTION action_generators.generate_if_any_user_attribute(in_params jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');

  v_check_attribute_id integer := data.get_attribute_id(json.get_string(in_params, 'attribute_code'));
  v_condition boolean;

  v_function text;
  v_params jsonb;
  v_ret_val jsonb;
begin
  select true
  into v_condition
  from data.attribute_values
  where
    object_id = v_user_object_id and
    attribute_id = v_check_attribute_id and
    value_object_id is null and
    value is not null;

  if v_condition is null then
    return null;
  end if;

  v_function := json.get_string(in_params, 'function');
  v_params :=
    json.get_opt_object(in_params, jsonb '{}', 'params') ||
    jsonb_build_object(
      'user_object_id', v_user_object_id,
      'object_id', json.get_opt_integer(in_params, null, 'object_id'));

  execute format('select action_generators.%s($1)', v_function)
  using v_params
  into v_ret_val;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
