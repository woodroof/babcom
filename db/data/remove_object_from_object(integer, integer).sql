-- Function: data.remove_object_from_object(integer, integer)

-- DROP FUNCTION data.remove_object_from_object(integer, integer);

CREATE OR REPLACE FUNCTION data.remove_object_from_object(
    in_object_id integer,
    in_parent_object_id integer)
  RETURNS void AS
$BODY$
declare
  v_connection_id integer;
begin
  assert in_object_id is not null;
  assert in_parent_object_id is not null;

  if in_object_id = in_parent_object_id then
    raise exception 'Attempt to remove object % from itself', in_object_id;
  end if;

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

  delete from data.object_objects
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
    );
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
