alter table data.clients add constraint clients_fk_objects
foreign key(actor_id) references data.objects(id);
