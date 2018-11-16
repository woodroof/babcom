alter table data.object_objects_journal add constraint object_objects_journal_fk_parent_object
foreign key(parent_object_id) references data.objects(id);
