-- drop trigger objects_trigger_after_insert on data.objects;

create trigger objects_trigger_after_insert
after insert
on data.objects
for each row
execute function data.objects_after_insert();
