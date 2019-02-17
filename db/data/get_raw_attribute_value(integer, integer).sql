-- drop function data.get_raw_attribute_value(integer, integer);

create or replace function data.get_raw_attribute_value(in_object_id integer, in_attribute_id integer)
returns jsonb
stable
as
$$
declare
  v_attribute_value jsonb;
begin
  assert data.is_class_or_object_exists(in_object_id);
  perform data.get_attribute_code(in_attribute_id);

  select value
  into v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    value_object_id is null;

  return v_attribute_value;
end;
$$
language plpgsql;
