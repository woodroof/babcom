-- drop function pallas_project.is_in_group(integer, text);

create or replace function pallas_project.is_in_group(in_object_id integer, in_group_code text)
returns boolean
volatile
as
$$
declare
  v_group_id integer := data.get_object_id(in_group_code);
  v_count integer; 
begin
  select count(1) into v_count from data.object_objects oo
  where oo.object_id = in_object_id
    and oo.parent_object_id = v_group_id;

  if v_count > 0 then
    return true;
  else 
    return false;
  end if;
end;
$$
language plpgsql;
