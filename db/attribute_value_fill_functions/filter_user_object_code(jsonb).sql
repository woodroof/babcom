-- Function: attribute_value_fill_functions.filter_user_object_code(jsonb)

-- DROP FUNCTION attribute_value_fill_functions.filter_user_object_code(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.filter_user_object_code(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_attribute_id integer := json.get_integer(in_params, 'attribute_id');
  v_attribute_value jsonb;
begin
  select value
  into v_attribute_value
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_attribute_id and
    value_object_id is null
  for share;

  if v_attribute_value is null then
    return;
  end if;

  perform json.get_string_array(v_attribute_value);

  v_attribute_value := v_attribute_value - data.get_object_code(v_user_object_id);

  perform data.set_attribute_value_if_changed(v_object_id, v_attribute_id, v_user_object_id, v_attribute_value, v_user_object_id);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
