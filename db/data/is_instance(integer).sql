-- drop function data.is_instance(integer);

create or replace function data.is_instance(in_object_id integer)
returns boolean
stable
as
$$
declare
  v_type data.object_type;
begin
  assert in_object_id is not null;

  select type
  into v_type
  from data.objects
  where id = in_object_id;

  assert v_type is not null;

  return v_type = 'instance';
end;
$$
language plpgsql;
