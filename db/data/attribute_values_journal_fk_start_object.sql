alter table data.attribute_values_journal add constraint attribute_values_journal_fk_start_object
foreign key(start_object_id) references data.objects(id);
