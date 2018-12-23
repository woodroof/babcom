alter table data.attribute_values_journal add constraint attribute_values_journal_fk_end_actor
foreign key(end_actor_id) references data.objects(id);
