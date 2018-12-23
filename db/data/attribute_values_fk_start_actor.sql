alter table data.attribute_values add constraint attribute_values_fk_start_actor
foreign key(start_actor_id) references data.objects(id);
