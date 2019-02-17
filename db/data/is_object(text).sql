-- drop function data.is_object(text);

create or replace function data.is_object(in_object_code text)
returns boolean
stable
as
$$
declare
  v_id integer;
begin
  assert in_object_code is not null;

  select id
  into v_id
  from data.objects
  where code = in_object_code;

  return (v_id is not null);
end;
$$
language plpgsql;
