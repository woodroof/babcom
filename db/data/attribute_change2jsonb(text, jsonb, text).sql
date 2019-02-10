-- drop function data.attribute_change2jsonb(text, jsonb, text);

create or replace function data.attribute_change2jsonb(in_attribute_code text, in_value jsonb, in_value_object_code text)
returns jsonb
volatile
as
$$
begin
  return data.attribute_change2jsonb(data.get_attribute_id(in_attribute_code), in_value, data.get_object_id(in_value_object_code));
end;
$$
language plpgsql;
