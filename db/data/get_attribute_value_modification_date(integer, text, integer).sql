-- drop function data.get_attribute_value_modification_date(integer, text, integer);

create or replace function data.get_attribute_value_modification_date(in_object_id integer, in_attribute_code text, in_value_object_id integer)
returns timestamp with time zone
stable
as
$$
begin
  return data.get_attribute_value_modification_date(in_object_id, data.get_attribute_id(in_attribute_code), in_value_object_id);
end;
$$
language 'plpgsql';
