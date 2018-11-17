alter table data.attribute_values_journal add constraint attribute_values_journal_fk_end_object
foreign key(end_object_id) references data.objects(id);
