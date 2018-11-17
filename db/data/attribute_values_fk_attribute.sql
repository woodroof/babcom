alter table data.attribute_values add constraint attribute_values_fk_attribute
foreign key(attribute_id) references data.attributes(id);
