-- drop function data.attribute_change2jsonb(integer, jsonb, text);

create or replace function data.attribute_change2jsonb(in_attribute_id integer, in_value jsonb, in_value_object_code text)
returns jsonb
stable
as
$$
begin
  return data.attribute_change2jsonb(in_attribute_id, in_value, data.get_object_id(in_value_object_code));
end;
$$
language plpgsql;
