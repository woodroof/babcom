-- drop function pallas_project.get_group_members_codes(text);

create or replace function pallas_project.get_group_members_codes(in_group_code text)
returns text[]
volatile
as
$$
declare
  v_objects text[] := array[]::text[];
  v_group_id integer := data.get_object_id(in_group_code);
begin
-- Список участников группы
  select array_agg(o.code) into v_objects
      from data.object_objects oo
      inner join data.objects o on oo.object_id = o.id
      where oo.parent_object_id = v_group_id
        and oo.parent_object_id <> oo.object_id;
  return v_objects;
end;
$$
language plpgsql;
