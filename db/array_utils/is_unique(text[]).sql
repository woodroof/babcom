-- drop function array_utils.is_unique(text[]);

create or replace function array_utils.is_unique(in_array text[])
returns boolean
immutable
as
$$
declare
  v_sorted_unique text[];
  v_sorted text[];
begin
  if in_array is null then
    return null;
  end if;

  select coalesce(array_agg(v.value), array[]::text[])
  from (
    select distinct value
    from unnest(in_array) a(value)
    order by value
  ) v
  into v_sorted_unique;

  select coalesce(array_agg(v.value), array[]::text[])
  from (
    select value
    from unnest(in_array) a(value)
    order by value
  ) v
  into v_sorted;

  return v_sorted_unique = v_sorted;
end;
$$
language 'plpgsql';
