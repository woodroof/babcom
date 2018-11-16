alter table data.object_objects_journal add constraint object_objects_journal_fk_object
foreign key(object_id) references data.objects(id);
