alter table data.notifications add constraint notifications_fk_connections
foreign key(connection_id) references data.connections(id);
