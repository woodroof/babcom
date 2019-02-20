-- drop function data.attribute_change2jsonb(text, jsonb, integer);

create or replace function data.attribute_change2jsonb(in_attribute_code text, in_value jsonb, in_value_object_id integer)
returns jsonb
stable
as
$$
begin
  return data.attribute_change2jsonb(data.get_attribute_id(in_attribute_code), in_value, in_value_object_id);
end;
$$
language plpgsql;
