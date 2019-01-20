-- drop function data.get_raw_attribute_value(integer, integer, integer);

create or replace function data.get_raw_attribute_value(in_object_id integer, in_attribute_id integer, in_value_object_id integer)
returns jsonb
stable
as
$$
declare
  v_object_exists boolean;
  v_attribute_value jsonb;
begin
  if in_value_object_id is null then
    select true
    into v_object_exists
    from data.objects
    where id = in_object_id;

    assert v_object_exists;
    perform data.get_attribute_code(in_attribute_id);

    select value
    into v_attribute_value
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id is null;
  else
    assert data.is_instance(in_object_id);
    assert data.can_attribute_be_overridden(in_attribute_id);

    select value
    into v_attribute_value
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id = in_value_object_id;
  end if;

  return v_attribute_value;
end;
$$
language plpgsql;
