alter table data.attribute_values_journal add constraint attribute_values_journal_fk_object
foreign key(object_id) references data.objects(id);
