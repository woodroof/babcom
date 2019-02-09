-- drop function data.get_object_class_id(integer);

create or replace function data.get_object_class_id(in_object_id integer)
returns integer
stable
as
$$
declare
  v_class_id integer;
begin
  assert data.is_instance(in_object_id);

  select class_id
  into v_class_id
  from data.objects
  where id = in_object_id;

  return v_class_id;
end;
$$
language plpgsql;
