alter table data.attribute_values add constraint attribute_values_fk_objects
foreign key(object_id) references data.objects(id);
