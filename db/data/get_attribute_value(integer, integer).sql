-- drop function data.get_attribute_value(integer, integer);

create or replace function data.get_attribute_value(in_object_id integer, in_attribute_id integer)
returns jsonb
stable
as
$$
declare
  v_attribute_value jsonb;
  v_class_id integer;
begin
  assert data.is_instance(in_object_id);
  assert data.can_attribute_be_overridden(in_attribute_id) is false;

  select value
  into v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    value_object_id is null;

  if v_attribute_value is null then
    select class_id
    into v_class_id
    from data.objects
    where id = in_object_id;

    if v_class_id is not null then
      select value
      into v_attribute_value
      from data.attribute_values
      where
        object_id = v_class_id and
        attribute_id = in_attribute_id and
        value_object_id is null;
    end if;
  end if;

  return v_attribute_value;
end;
$$
language 'plpgsql';
