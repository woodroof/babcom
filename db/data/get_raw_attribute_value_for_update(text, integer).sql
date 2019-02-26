-- drop function data.get_raw_attribute_value_for_update(text, integer);

create or replace function data.get_raw_attribute_value_for_update(in_object_code text, in_attribute_id integer)
returns jsonb
volatile
as
$$
begin
  return data.get_raw_attribute_value_for_update(data.get_object_id(in_object_code), in_attribute_id);
end;
$$
language plpgsql;
