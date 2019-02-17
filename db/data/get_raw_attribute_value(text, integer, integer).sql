-- drop function data.get_raw_attribute_value(text, integer, integer);

create or replace function data.get_raw_attribute_value(in_object_code text, in_attribute_id integer, in_value_object_id integer)
returns jsonb
stable
as
$$
begin
  return data.get_raw_attribute_value(data.get_object_id(in_object_code), in_attribute_id, in_value_object_id);
end;
$$
language plpgsql;
