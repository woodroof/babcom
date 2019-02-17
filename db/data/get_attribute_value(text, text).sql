-- drop function data.get_attribute_value(text, text);

create or replace function data.get_attribute_value(in_object_code text, in_attribute_code text)
returns jsonb
stable
as
$$
begin
  return data.get_attribute_value(data.get_object_id(in_object_code), data.get_attribute_id(in_attribute_code));
end;
$$
language plpgsql;
