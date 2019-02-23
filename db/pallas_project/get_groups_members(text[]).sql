-- drop function pallas_project.get_groups_members(text[]);

create or replace function pallas_project.get_groups_members(in_group_codes text[])
returns integer[]
volatile
as
$$
declare
  v_objects integer[] := array[]::integer[];
begin
-- Список участников групп без дублирований
  select array_agg(distinct oo.object_id) into v_objects
      from data.object_objects oo
      where oo.parent_object_id in (select data.get_object_id(unnest) from unnest(in_group_codes)) 
        and oo.parent_object_id <> oo.object_id;

  if v_objects is null then
    v_objects := array[]::integer[];
  end if;
  return v_objects;
end;
$$
language plpgsql;
