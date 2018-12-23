alter table data.clients add constraint clients_fk_logins
foreign key(login_id) references data.logins(id);
