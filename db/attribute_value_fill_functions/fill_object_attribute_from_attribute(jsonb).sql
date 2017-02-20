-- Function: attribute_value_fill_functions.fill_object_attribute_from_attribute(jsonb)

-- DROP FUNCTION attribute_value_fill_functions.fill_object_attribute_from_attribute(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.fill_object_attribute_from_attribute(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_attribute_id integer := json.get_integer(in_params, 'attribute_id');
  v_source_attribute_id integer := data.get_attribute_id(json.get_string(in_params, 'attribute_code'));
  v_attribute_value jsonb;
begin
  select value
  into v_attribute_value
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_source_attribute_id and
    value_object_id is null
  for share;

  if v_attribute_value is null then
    perform data.delete_attribute_value_if_exists(v_object_id, v_attribute_id, v_object_id, v_user_object_id);
    return;
  end if;

  perform data.set_attribute_value_if_changed(v_object_id, v_attribute_id, v_object_id, v_attribute_value, v_user_object_id);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
