-- drop function data.should_attribute_value_be_changed(integer, integer, integer, integer, integer);

create or replace function data.should_attribute_value_be_changed(in_object_id integer, in_source_attribute_id integer, in_source_value_object_id integer, in_destination_attribute_id integer, in_destination_value_object_id integer)
returns boolean
stable
as
$$
declare
  v_source_attribute_modification_date timestamp with time zone :=
    data.get_attribute_value_modification_date(in_object_id, in_source_attribute_id, in_source_value_object_id);
  v_destination_attribute_modification_date timestamp with time zone :=
    data.get_attribute_value_modification_date(in_object_id, in_destination_attribute_id, in_destination_value_object_id);
begin
  return
    v_destination_attribute_modification_date is null and v_source_attribute_modification_date is not null or
    v_source_attribute_modification_date is null and v_destination_attribute_modification_date is not null or
    v_source_attribute_modification_date > v_destination_attribute_modification_date;
end;
$$
language plpgsql;
