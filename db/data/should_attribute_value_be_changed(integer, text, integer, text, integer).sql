-- drop function data.should_attribute_value_be_changed(integer, text, integer, text, integer);

create or replace function data.should_attribute_value_be_changed(in_object_id integer, in_source_attribute_code text, in_source_value_object_id integer, in_destination_attribute_code text, in_destination_value_object_id integer)
returns boolean
stable
as
$$
begin
  return data.should_attribute_value_be_changed(
    in_object_id,
    data.get_attribute_id(in_source_attribute_code),
    in_source_value_object_id,
    data.get_attribute_id(in_destination_attribute_code),
    in_destination_value_object_id);
end;
$$
language plpgsql;
