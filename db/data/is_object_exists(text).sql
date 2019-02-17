-- drop function data.is_object_exists(text);

create or replace function data.is_object_exists(in_object_code text)
returns boolean
stable
as
$$
declare
  v_exists boolean;
begin
  assert in_object_code is not null;

  select true
  into v_exists
  from data.objects
  where
    code = in_object_code and
    type = 'instance';

  return coalesce(v_exists, false);
end;
$$
language plpgsql;
