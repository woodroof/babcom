-- drop function array_utils.is_unique(integer[]);

create or replace function array_utils.is_unique(in_array integer[])
returns boolean
immutable
as
$$
begin
  return intarray.uniq(intarray.sort(in_array)) = intarray.sort(in_array);
end;
$$
language 'plpgsql';
