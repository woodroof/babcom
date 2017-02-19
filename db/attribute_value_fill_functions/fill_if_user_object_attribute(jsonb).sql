-- Function: attribute_value_fill_functions.fill_if_user_object_attribute(jsonb)

-- DROP FUNCTION attribute_value_fill_functions.fill_if_user_object_attribute(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.fill_if_user_object_attribute(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
begin
  if v_user_object_id != v_object_id then
    return;
  end if;

  perform attribute_value_fill_functions.fill_if_object_attribute(in_params);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
