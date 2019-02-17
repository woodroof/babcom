-- drop function data.get_attribute_value_for_share(text, text);

create or replace function data.get_attribute_value_for_share(in_object_code text, in_attribute_code text)
returns jsonb
volatile
as
$$
begin
  return data.get_attribute_value_for_share(data.get_object_id(in_object_code), data.get_attribute_id(in_attribute_code));
end;
$$
language plpgsql;
