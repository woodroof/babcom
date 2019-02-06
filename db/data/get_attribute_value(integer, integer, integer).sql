-- drop function data.get_attribute_value(integer, integer, integer);

create or replace function data.get_attribute_value(in_object_id integer, in_attribute_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_priority_attribute_id integer := data.get_attribute_id('priority');
  v_attribute_value jsonb;
  v_class_id integer;
begin
  assert data.is_instance(in_object_id);
  assert data.is_instance(in_actor_id);
  assert data.can_attribute_be_overridden(in_attribute_id);

  select av.value
  into v_attribute_value
  from data.attribute_values av
  left join data.object_objects oo on
    av.value_object_id = oo.parent_object_id and
    oo.object_id = in_actor_id
  left join data.attribute_values pr on
    pr.object_id = av.value_object_id and
    pr.attribute_id = v_priority_attribute_id and
    pr.value_object_id is null
  left join data.objects o on
    o.id = av.value_object_id and
    pr.id is null
  left join data.attribute_values pr2 on
    pr2.object_id = o.class_id and
    pr2.attribute_id = v_priority_attribute_id and
    pr2.value_object_id is null
  where
    av.object_id = in_object_id and
    av.attribute_id = in_attribute_id and
    (
      av.value_object_id is null or
      oo.id is not null
    )
  order by json.get_integer_opt(coalesce(pr2.value, pr.value), 0) desc
  limit 1;

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
language plpgsql;
