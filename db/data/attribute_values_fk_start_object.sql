alter table data.attribute_values add constraint attribute_values_fk_start_object
foreign key(start_object_id) references data.objects(id);
