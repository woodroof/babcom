-- drop function data.get_raw_attribute_value_for_update(text, text, integer);

create or replace function data.get_raw_attribute_value_for_update(in_object_code text, in_attribute_code text, in_value_object_id integer)
returns jsonb
volatile
as
$$
begin
  return data.get_raw_attribute_value_for_update(data.get_object_id(in_object_code), data.get_attribute_id(in_attribute_code), in_value_object_id);
end;
$$
language plpgsql;
