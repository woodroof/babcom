-- drop function data.objects_after_insert();

create or replace function data.objects_after_insert()
returns trigger
volatile
as
$$
begin
  insert into data.object_objects(parent_object_id, object_id)
  values(new.id, new.id);

  return null;
end;
$$
language 'plpgsql';
