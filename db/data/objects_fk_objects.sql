alter table data.objects add constraint objects_fk_objects
foreign key(class_id) references data.objects(id);
