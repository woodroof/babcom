-- Function: attribute_value_fill_functions.fill_user_object_attribute_from_attribute(jsonb)

-- DROP FUNCTION attribute_value_fill_functions.fill_user_object_attribute_from_attribute(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.fill_user_object_attribute_from_attribute(in_params jsonb)
  RETURNS void AS
$BODY$
begin
  perform attribute_value_fill_functions.fill_value_object_attribute_from_attribute(
    jsonb_build_object('value_object_code', data.get_object_code(json.get_integer(in_params, 'user_object_id'))) ||
    in_params);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
