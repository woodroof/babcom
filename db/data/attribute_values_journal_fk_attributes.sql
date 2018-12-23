alter table data.attribute_values_journal add constraint attribute_values_journal_fk_attributes
foreign key(attribute_id) references data.attributes(id);
