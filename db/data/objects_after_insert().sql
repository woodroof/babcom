-- Function: data.objects_after_insert()

-- DROP FUNCTION data.objects_after_insert();

CREATE OR REPLACE FUNCTION data.objects_after_insert()
  RETURNS trigger AS
$BODY$
begin
  insert into data.object_objects(parent_object_id, object_id)
  values (new.id, new.id);

  return null;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
