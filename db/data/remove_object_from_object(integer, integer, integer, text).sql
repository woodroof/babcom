-- drop function data.remove_object_from_object(integer, integer, integer, text);

create or replace function data.remove_object_from_object(in_object_id integer, in_parent_object_id integer, in_actor_id integer default null::integer, in_reason text default null::text)
returns void
volatile
as
$$
-- Как правило вместо этой функции следует вызывать data.change_object_groups
declare
  v_connection_id integer;
  v_ids integer[];
begin
  assert data.is_instance(in_object_id);
  assert data.is_instance(in_parent_object_id);
  assert in_actor_id is null or data.is_instance(in_actor_id);

  if in_object_id = in_parent_object_id then
    raise exception 'Attempt to remove object % from itself', in_object_id;
  end if;

  -- Блокируем запись, чтобы параллельно с нами никто не удалил из той же группы
  select id
  into v_connection_id
  from data.object_objects
  where
    parent_object_id = in_parent_object_id and
    object_id = in_object_id and
    intermediate_object_ids is null
  for update;

  if v_connection_id is null then
    raise exception 'Attempt to remove non-existing connection from object % to object %', in_object_id, in_parent_object_id;
  end if;

  -- Блокируем parent'ы и child'ы на чтение, чтобы никто за это время не поменял нужные нам группы
  perform *
  from data.object_objects
  where
    id in (
      select oo.id
      from (
        select array_agg(os.value) as value
        from
        (
          select distinct(object_id) as value
          from data.object_objects
          where parent_object_id = in_object_id
        ) os
      ) o
      join (
        select array_agg(ps.value) as value
        from
        (
          select distinct(parent_object_id) as value
          from data.object_objects
          where object_id = in_parent_object_id
        ) ps
      ) po
      on true
      join data.object_objects oo
      on
        (
          (
            oo.parent_object_id = any(o.value) and
            oo.object_id = any(o.value)
          ) or
          (
            oo.parent_object_id = any(po.value) and
            oo.object_id = any(po.value)
          )
        ) and
        oo.intermediate_object_ids is null
    )
  for share;

  select array_agg(i.id)
  into v_ids
  from (
    select oo.id
    from (
      select array_agg(os.value) as value
      from
      (
        select distinct(object_id) as value
        from data.object_objects
        where parent_object_id = in_object_id
      ) os
    ) o
    join (
      select array_agg(ps.value) as value
      from
      (
        select distinct(parent_object_id) as value
        from data.object_objects
        where object_id = in_parent_object_id
      ) ps
    ) po
    on true
    join data.object_objects oo
    on
      parent_object_id = any(po.value) and
      object_id = any(o.value) and
      array_position(intermediate_object_ids, in_object_id) = array_position(intermediate_object_ids, in_parent_object_id) - 1
    union
    select id
    from data.object_objects
    where
      object_id = in_object_id and
      intermediate_object_ids[1] = in_parent_object_id
    union
    select id
    from data.object_objects
    where
      parent_object_id = in_parent_object_id and
      intermediate_object_ids[array_length(intermediate_object_ids, 1)] = in_object_id
    union
    select v_connection_id
  ) i;

  insert into data.object_objects_journal(parent_object_id, object_id, intermediate_object_ids, start_time, start_reason, start_actor_id, end_time, end_reason, end_actor_id)
  select parent_object_id, object_id, intermediate_object_ids, start_time, start_reason, start_actor_id, clock_timestamp(), in_reason, in_actor_id
  from data.object_objects
  where id = any(v_ids);

  delete from data.object_objects
  where id = any(v_ids);
end;
$$
language plpgsql;
