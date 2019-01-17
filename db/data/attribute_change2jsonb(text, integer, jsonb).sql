-- drop function data.attribute_change2jsonb(text, integer, jsonb);

create or replace function data.attribute_change2jsonb(in_attribute_code text, in_value_object_id integer, in_value jsonb)
returns jsonb
volatile
as
$$
begin
  return data.attribute_change2jsonb(data.get_attribute_id(in_attribute_code), in_value_object_id, in_value);
end;
$$
language 'plpgsql';
