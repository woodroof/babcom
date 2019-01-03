-- drop function data.get_attribute_value(integer, text);

create or replace function data.get_attribute_value(in_object_id integer, in_attribute_name text)
returns jsonb
volatile
as
$$
declare
  v_attribute_id integer := data.get_attribute_id(in_attribute_name);
  v_attribute_value jsonb;
begin
  assert in_object_id is not null;
  assert data.can_attribute_be_overridden(v_attribute_id) is false;

  select value
  into v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = v_attribute_id and
    value_object_id is null;

  return v_attribute_value;
end;
$$
language 'plpgsql';
