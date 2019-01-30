alter table data.object_objects_journal add constraint object_objects_journal_fk_end_actor
foreign key(end_actor_id) references data.objects(id);
