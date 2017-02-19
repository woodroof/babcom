-- Function: attribute_value_change_functions.json_to_attribute_system_meta(jsonb)

-- DROP FUNCTION attribute_value_change_functions.json_to_attribute_system_meta(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_change_functions.json_to_attribute_system_meta(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_user_object_id integer := json.get_opt_integer(in_params, null, 'user_object_id');
  v_attribute_id integer := json.get_integer(in_params, 'attribute_id');
  v_attribute_value jsonb;
  v_attribute_system_meta_id integer := data.get_attribute_id('system_meta');
begin
  v_attribute_value := data.get_attribute_value(v_object_id, v_object_id, v_attribute_id);

  perform data.delete_attribute_value_if_exists(v_object_id, v_attribute_system_meta_id, av.value_object_id, v_user_object_id)
    from data.attribute_values av
    where av.object_id = v_object_id and
          av.attribute_id = v_attribute_system_meta_id and
          av.value_object_id is not null and
          av.value_object_id not in (select data.get_object_id(member) from jsonb_to_recordset(v_attribute_value) as (member text));

  perform data.set_attribute_value_if_changed(v_object_id, v_attribute_system_meta_id, data.get_object_id(member), jsonb 'true', v_user_object_id)
    from jsonb_to_recordset(v_attribute_value) as (member text);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
  