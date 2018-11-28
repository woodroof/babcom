alter table data.log add constraint log_fk_objects
foreign key(actor_id) references data.objects(id);
