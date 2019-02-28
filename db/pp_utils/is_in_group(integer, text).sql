-- drop function pp_utils.is_in_group(integer, text);

create or replace function pp_utils.is_in_group(in_object_id integer, in_group_code text)
returns boolean
stable
as
$$
begin
  return pp_utils.is_in_group(in_object_id, data.get_object_id(in_group_code));
end;
$$
language plpgsql;
