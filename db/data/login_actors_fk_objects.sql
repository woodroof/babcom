alter table data.login_actors add constraint login_actors_fk_objects
foreign key(actor_id) references data.objects(id);
