-- drop table data.notifications;

create table data.notifications(
  id text not null default (pgcrypto.gen_random_uuid())::text,
  message jsonb not null,
  client_id text not null,
  constraint notifications_pk primary key(id),
  constraint notifications_fk_connections foreign key(client_id) references data.connections(client_id)
);
