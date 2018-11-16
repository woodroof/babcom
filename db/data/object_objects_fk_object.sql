alter table data.object_objects add constraint object_objects_fk_object
foreign key(object_id) references data.objects(id);
