-- drop function data.get_raw_attribute_value_for_share(integer, integer);

create or replace function data.get_raw_attribute_value_for_share(in_object_id integer, in_attribute_id integer)
returns jsonb
volatile
as
$$
declare
  v_id integer;
  v_attribute_value jsonb;
begin
  -- Блокировать класс неправильно, слишком большая видимость
  assert data.is_instance(in_object_id);
  perform data.get_attribute_code(in_attribute_id);

  select id, value
  into v_id, v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    value_object_id is null
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
