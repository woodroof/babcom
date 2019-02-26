-- drop function data.get_raw_attribute_value_for_share(text, integer, integer);

create or replace function data.get_raw_attribute_value_for_share(in_object_code text, in_attribute_id integer, in_value_object_id integer)
returns jsonb
volatile
as
$$
begin
  return data.get_raw_attribute_value_for_share(data.get_object_id(in_object_code), in_attribute_id, in_value_object_id);
end;
$$
language plpgsql;
