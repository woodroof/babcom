-- drop function data.get_raw_attribute_value_for_share(integer, integer, integer);

create or replace function data.get_raw_attribute_value_for_share(in_object_id integer, in_attribute_id integer, in_value_object_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_exists boolean;
  v_id integer;
  v_attribute_value jsonb;
begin
  if in_value_object_id is null then
    return data.get_raw_attribute_value_for_share(in_object_id, in_attribute_id);
  end if;

  -- Блокировать класс неправильно, слишком большая видимость
  assert data.is_instance(in_object_id);
  assert data.is_instance(in_value_object_id);
  assert data.can_attribute_be_overridden(in_attribute_id);

  select id, value
  into v_id, v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    value_object_id = in_value_object_id
  for share;

  if v_id is null then
    perform
    from data.objects
    where id = in_object_id
    for share;
  end if;

  return v_attribute_value;
end;
$$
language plpgsql;
