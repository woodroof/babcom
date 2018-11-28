alter table data.notifications add constraint notifications_fk_clients
foreign key(client_id) references data.clients(id);
