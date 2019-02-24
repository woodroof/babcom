-- drop function pp_utils.is_in_group(integer, text);

create or replace function pp_utils.is_in_group(in_object_id integer, in_group_code text)
returns boolean
stable
as
$$
declare
  v_group_id integer := data.get_object_id(in_group_code);
  v_exists boolean; 
begin
  select true
  into v_exists
  where exists(
    select 1
    from data.object_objects
    where
      object_id = in_object_id and
      parent_object_id = v_group_id);

  if v_exists then
    return true;
  end if;

  return false;
end;
$$
language plpgsql;
