-- drop function data.get_attribute_value_modification_date(integer, integer, integer);

create or replace function data.get_attribute_value_modification_date(in_object_id integer, in_attribute_id integer, in_value_object_id integer)
returns timestamp with time zone
stable
as
$$
declare
  v_date timestamp with time zone;
begin
  -- Странно пользоваться этой функцией, если мы работаем с атрибутами классов
  assert data.is_instance(in_object_id);
  perform data.get_attribute_code(in_attribute_id);

  if in_value_object_id is null then
    select start_time
    into v_date
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id is null;
  else
    select start_time
    into v_date
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id = in_value_object_id;
  end if;

  return v_date;
end;
$$
language plpgsql;
