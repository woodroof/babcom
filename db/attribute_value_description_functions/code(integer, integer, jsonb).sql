-- Function: attribute_value_description_functions.code(integer, integer, jsonb)

-- DROP FUNCTION attribute_value_description_functions.code(integer, integer, jsonb);

CREATE OR REPLACE FUNCTION attribute_value_description_functions.code(
    in_user_object_id integer,
    in_attribute_id integer,
    in_value jsonb)
  RETURNS text AS
$BODY$
declare
  v_object_id integer :=
    data.get_object_id(
      json.get_string(in_value));
begin
  return
    coalesce(
      json.get_opt_string(
        data.get_attribute_value(in_user_object_id, v_object_id, data.get_attribute_id('name'))),
      'Инкогнито');
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
