-- Function: data.get_raw_attribute_value(integer, integer, integer)

-- DROP FUNCTION data.get_raw_attribute_value(integer, integer, integer);

CREATE OR REPLACE FUNCTION data.get_raw_attribute_value(
    in_object_id integer,
    in_attribute_id integer,
    in_value_object_id integer)
  RETURNS jsonb AS
$BODY$
declare
  v_ret_val jsonb;
begin
  if in_value_object_id is null then
    select value
    into v_ret_val
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id is null;
  else
    select value
    into v_ret_val
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id = in_value_object_id;
  end if;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
