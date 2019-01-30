alter table data.object_objects_journal add constraint object_objects_journal_fk_start_actor
foreign key(start_actor_id) references data.objects(id);
