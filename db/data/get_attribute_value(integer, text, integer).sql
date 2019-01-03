-- drop function data.get_attribute_value(integer, text, integer);

create or replace function data.get_attribute_value(in_object_id integer, in_attribute_name text, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_attribute_id integer := data.get_attribute_id(in_attribute_name);
  v_priority_attribute_id integer := data.get_attribute_id('priority');
  v_attribute_value jsonb;
begin
  assert in_object_id is not null;
  assert in_actor_id is not null;
  assert data.can_attribute_be_overridden(v_attribute_id) is true;

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
  where
    av.object_id = in_object_id and
    av.attribute_id = v_attribute_id and
    (
      av.value_object_id is null or
      oo.id is not null
    )
  order by json.get_integer_opt(pr.value, 0) desc
  limit 1;

  return v_attribute_value;
end;
$$
language 'plpgsql';
