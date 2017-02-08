-- Function: data.get_attribute_value(integer, integer, integer)

-- DROP FUNCTION data.get_attribute_value(integer, integer, integer);

CREATE OR REPLACE FUNCTION data.get_attribute_value(
    in_user_object_id integer,
    in_object_id integer,
    in_attribute_id integer)
  RETURNS jsonb AS
$BODY$
declare
  v_ret_val jsonb;
  v_system_priority_attr_id integer := data.get_attribute_id('system_priority');
begin
  assert in_user_object_id is not null;
  assert in_object_id is not null;
  assert in_attribute_id is not null;

  select av.value
  into v_ret_val
  from data.attribute_values av
  left join data.object_objects oo on
    av.value_object_id = oo.parent_object_id and
    oo.object_id = in_user_object_id
  left join data.attribute_values pr on
    pr.object_id = av.value_object_id and
    pr.attribute_id = v_system_priority_attr_id and
    pr.value_object_id is null
  where
    av.object_id = in_object_id and
    av.attribute_id = in_attribute_id and
    (
      av.value_object_id is null or
      oo.id is not null
    )
  order by json.get_opt_integer(pr.value, 0) desc
  limit 1;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
