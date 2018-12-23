alter table data.attribute_values add constraint attribute_values_fk_attributes
foreign key(attribute_id) references data.attributes(id);
