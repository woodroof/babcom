-- drop function data.get_attribute_value_for_share(integer, text);

create or replace function data.get_attribute_value_for_share(in_object_id integer, in_attribute_code text)
returns jsonb
volatile
as
$$
begin
  return data.get_attribute_value_for_share(in_object_id, data.get_attribute_id(in_attribute_code));
end;
$$
language plpgsql;
