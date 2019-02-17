-- drop function data.get_raw_attribute_value(integer, text, text);

create or replace function data.get_raw_attribute_value(in_object_id integer, in_attribute_code text, in_value_object_code text)
returns jsonb
stable
as
$$
begin
  return data.get_raw_attribute_value(in_object_id, data.get_attribute_id(in_attribute_code), data.get_object_id(in_value_object_code));
end;
$$
language plpgsql;
