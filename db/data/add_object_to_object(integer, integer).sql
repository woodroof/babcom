-- drop function data.add_object_to_object(integer, integer);

create or replace function data.add_object_to_object(in_object_id integer, in_parent_object_id integer)
returns void
volatile
as
$$
declare
  v_exists boolean;
  v_cycle boolean;
  v_row record;
begin
  assert data.is_instance(in_object_id);
  assert data.is_instance(in_parent_object_id);

  if in_object_id = in_parent_object_id then
    raise exception 'Attempt to add object % to itself', in_object_id;
  end if;

  perform *
  from data.object_objects
  where
    (
      parent_object_id = in_parent_object_id and
      object_id = in_parent_object_id
    ) or
    (
      parent_object_id = in_object_id and
      object_id = in_object_id
    )
  for update;

  select true
  into v_exists
  from data.object_objects
  where
    parent_object_id = in_parent_object_id and
    object_id = in_object_id and
    intermediate_object_ids is null;

  if v_exists is not null then
    raise exception 'Connection from object % to object % already exists!', in_object_id, in_parent_object_id;
  end if;

  select true
  into v_cycle
  from data.object_objects
  where
    parent_object_id = in_object_id and
    object_id = in_parent_object_id;

  if v_cycle is not null then
    raise exception 'Cycle detected while adding object % to object %!', in_object_id, in_parent_object_id;
  end if;

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
        oo.parent_object_id != oo.object_id and
        oo.intermediate_object_ids is null
    )
  for share;

  insert into data.object_objects(parent_object_id, object_id, intermediate_object_ids)
  select
    oo2.parent_object_id,
    oo1.object_id,
    oo1.intermediate_object_ids || in_object_id || in_parent_object_id || oo2.intermediate_object_ids
  from data.object_objects oo1
  join data.object_objects oo2
  on
    oo1.parent_object_id = in_object_id and
    oo1.object_id != oo1.parent_object_id and
    oo2.object_id = in_parent_object_id and
    oo2.object_id != oo2.parent_object_id
  union
  select
    oo.parent_object_id,
    in_object_id,
    in_parent_object_id || oo.intermediate_object_ids
  from data.object_objects oo
  where
    oo.object_id = in_parent_object_id and
    oo.object_id != oo.parent_object_id
  union
  select
    in_parent_object_id,
    oo.object_id,
    oo.intermediate_object_ids || in_object_id
  from data.object_objects oo
  where
    oo.parent_object_id = in_object_id and
    oo.object_id != oo.parent_object_id
  union
  select in_parent_object_id, in_object_id, null;
end;
$$
language plpgsql;
