-- drop function data.set_attribute_value(integer, integer, jsonb, integer, integer, text);

create or replace function data.set_attribute_value(in_object_id integer, in_attribute_id integer, in_value jsonb, in_value_object_id integer, in_actor_id integer, in_reason text default null::text)
returns void
volatile
as
$$
-- Как правило вместо этой функции следует вызывать data.change_object
declare
  v_attribute_value record;
begin
  assert data.is_instance(in_object_id);
  assert in_attribute_id is not null;
  assert in_value is not null;

  if in_value_object_id is null then
    select id, object_id, attribute_id, value_object_id, value, start_time, start_reason, start_actor_id
    into v_attribute_value
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id is null;
  else
    assert data.can_attribute_be_overridden(in_attribute_id);

    select id, object_id, attribute_id, value_object_id, value, start_time, start_reason, start_actor_id
    into v_attribute_value
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id = in_value_object_id;
  end if;

  if v_attribute_value is null then
    insert into data.attribute_values(object_id, attribute_id, value_object_id, value, start_reason, start_actor_id)
    values(in_object_id, in_attribute_id, in_value_object_id, in_value, in_reason, in_actor_id);
  else
    insert into data.attribute_values_journal(
      object_id,
      attribute_id,
      value_object_id,
      value,
      start_time,
      start_reason,
      start_actor_id,
      end_time,
      end_reason,
      end_actor_id)
    values(
      in_object_id,
      in_attribute_id,
      in_value_object_id,
      v_attribute_value.value,
      v_attribute_value.start_time,
      v_attribute_value.start_reason,
      v_attribute_value.start_actor_id,
      now(),
      in_reason,
      in_actor_id);

    update data.attribute_values
    set
      value = in_value,
      start_time = now(),
      start_reason = in_reason,
      start_actor_id = in_actor_id
    where id = v_attribute_value.id;
  end if;
end;
$$
language 'plpgsql';
