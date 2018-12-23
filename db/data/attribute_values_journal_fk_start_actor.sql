alter table data.attribute_values_journal add constraint attribute_values_journal_fk_start_actor
foreign key(start_actor_id) references data.objects(id);
