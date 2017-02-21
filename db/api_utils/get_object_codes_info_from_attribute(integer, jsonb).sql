-- Function: api_utils.get_object_codes_info_from_attribute(integer, jsonb)

-- DROP FUNCTION api_utils.get_object_codes_info_from_attribute(integer, jsonb);

CREATE OR REPLACE FUNCTION api_utils.get_object_codes_info_from_attribute(
    in_user_object_id integer,
    in_params jsonb)
  RETURNS text[] AS
$BODY$
declare
  v_object_code text := json.get_string(in_params, 'object_code');
  v_attribute_code text := json.get_string(in_params, 'attribute_code');

  v_object_id integer := data.get_object_id(v_object_code);
  v_attribute_id integer := data.get_attribute_id(v_attribute_code);
  v_system_is_visible_attribute_id integer := data.get_attribute_id('system_is_visible');

  v_attribute_value jsonb;
begin
  assert in_user_object_id is not null;

  if data.is_system_attribute(v_attribute_id) then
    perform utils.raise_invalid_input_param_value('Can''t find attribute "%s"', v_attribute_code);
  end if;

  perform data.fill_attribute_values(in_user_object_id, array[v_object_id], array[v_system_is_visible_attribute_id]);

  if not data.is_object_visible(in_user_object_id, v_object_id) then
    perform utils.raise_invalid_input_param_value('Can''t find object "%s"', v_object_code);
  end if;

  perform data.fill_attribute_values(in_user_object_id, array[v_object_id], array[v_attribute_id]);

  v_attribute_value := data.get_attribute_value(in_user_object_id, v_object_id, v_attribute_id);

  if v_attribute_value is null then
    return null;
  end if;

  return json.get_opt_string_array(v_attribute_value);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
