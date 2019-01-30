alter table data.object_objects add constraint object_objects_fk_start_actor
foreign key(start_actor_id) references data.objects(id);
