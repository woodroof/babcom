-- drop function data.is_class_or_object_exists(integer);

create or replace function data.is_class_or_object_exists(in_object_id integer)
returns boolean
stable
as
$$
declare
  v_exists boolean;
begin
  assert in_object_id is not null;

  select true
  into v_exists
  from data.objects
  where id = in_object_id;

  return coalesce(v_exists, false);
end;
$$
language plpgsql;
