-- Function: attribute_value_change_functions.any_value_to_object(jsonb)

-- DROP FUNCTION attribute_value_change_functions.any_value_to_object(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_change_functions.any_value_to_object(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_value_object_id integer := json.get_opt_integer(in_params, null, 'value_object_id');
  v_old_value jsonb := in_params->'old_value';
  v_new_value jsonb := in_params->'new_value';
  v_object_code text := json.get_string(in_params, 'object_code');
begin
  if v_value_object_id is not null then
    return;
  end if;

  if
    v_old_value is not null and
    v_new_value is null
  then
    perform data.remove_object_from_object(
      v_object_id,
      data.get_object_id(v_object_code));
  end if;

  if
    v_new_value is not null and
    v_old_value is null
  then
    perform data.add_object_to_object(
      v_object_id,
      data.get_object_id(v_object_code));
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
