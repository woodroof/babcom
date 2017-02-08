-- Function: data.get_attribute_value_for_update(integer, integer, integer)

-- DROP FUNCTION data.get_attribute_value_for_update(integer, integer, integer);

CREATE OR REPLACE FUNCTION data.get_attribute_value_for_update(
    in_object_id integer,
    in_attribute_id integer,
    in_value_object_id integer)
  RETURNS jsonb AS
$BODY$
declare
  v_ret_val jsonb;
begin
  select value
  into v_ret_val
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    (
      value_object_id = in_value_object_id or
      (
        value_object_id is null and
        in_value_object_id is null
      )
    )
  for update;

  if v_ret_val is null then
    perform id
    from data.objects
    where id = in_object_id
    for update;

    select value
    into v_ret_val
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      (
        value_object_id = in_value_object_id or
        (
          value_object_id is null and
          in_value_object_id is null
        )
      )
    for update;
  end if;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
