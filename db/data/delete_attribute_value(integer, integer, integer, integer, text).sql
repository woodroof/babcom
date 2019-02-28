-- drop function data.delete_attribute_value(integer, integer, integer, integer, text);

create or replace function data.delete_attribute_value(in_object_id integer, in_attribute_id integer, in_value_object_id integer, in_actor_id integer default null::integer, in_reason text default null::text)
returns void
volatile
as
$$
-- Как правило вместо этой функции следует вызывать data.change_object
-- Эта функция не проставляет правильно блокировки и не рассылает уведомлений
declare
  v_attribute_value_id integer;
begin
  assert data.is_instance(in_object_id);
  assert in_attribute_id is not null;
  assert in_actor_id is null or data.is_instance(in_actor_id);

  if in_value_object_id is null then
    select id
    into v_attribute_value_id
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id is null;
  else
    select id
    into v_attribute_value_id
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id = in_value_object_id;
  end if;

  assert v_attribute_value_id is not null;

  insert into data.attribute_values_journal(object_id, attribute_id, value_object_id, value, start_time, start_reason, start_actor_id, end_time, end_reason, end_actor_id)
  select object_id, attribute_id, value_object_id, value, start_time, start_reason, start_actor_id, clock_timestamp(), in_reason, in_actor_id
  from data.attribute_values
  where id = v_attribute_value_id;

  delete from data.attribute_values
  where id = v_attribute_value_id;
end;
$$
language plpgsql;
