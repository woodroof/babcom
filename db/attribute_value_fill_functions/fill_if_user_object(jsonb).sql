-- Function: attribute_value_fill_functions.fill_if_user_object(jsonb)

-- DROP FUNCTION attribute_value_fill_functions.fill_if_user_object(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.fill_if_user_object(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_function text;
  v_params jsonb;
begin
  if v_user_object_id != v_object_id then
    return;
  end if;

  v_function := json.get_string(in_params, 'function');
  v_params :=
    json.get_opt_object(in_params, jsonb '{}', 'params') ||
    jsonb_build_object(
      'user_object_id', v_user_object_id,
      'object_id', v_object_id,
      'attribute_id', json.get_integer(in_params, 'attribute_id'));

  execute format('select attribute_value_fill_functions.%s($1)', v_function)
  using v_params;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
