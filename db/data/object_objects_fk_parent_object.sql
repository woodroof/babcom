alter table data.object_objects add constraint object_objects_fk_parent_object
foreign key(parent_object_id) references data.objects(id);
