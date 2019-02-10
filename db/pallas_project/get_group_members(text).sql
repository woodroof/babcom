-- drop function pallas_project.get_group_members(text);

create or replace function pallas_project.get_group_members(in_group_code text)
returns integer[]
volatile
as
$$
declare
  v_objects integer[] := array[]::integer[];
  v_group_id integer := data.get_object_id(in_group_code);
begin
-- Список участников группы
  select array_agg(oo.object_id) into v_objects
      from data.object_objects oo
      where oo.parent_object_id = v_group_id
        and oo.parent_object_id <> oo.object_id;
  return v_objects;
end;
$$
language plpgsql;
