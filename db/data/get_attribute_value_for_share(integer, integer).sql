-- drop function data.get_attribute_value_for_share(integer, integer);

create or replace function data.get_attribute_value_for_share(in_object_id integer, in_attribute_id integer)
returns jsonb
volatile
as
$$
declare
  v_id integer;
  v_attribute_value jsonb;
  v_class_id integer;
begin
  assert data.is_instance(in_object_id);
  assert not data.can_attribute_be_overridden(in_attribute_id);

  select id, value
  into v_id, v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    value_object_id is null
  for share;

  if v_id is null then
    v_class_id := data.get_object_class_id(in_object_id);

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
