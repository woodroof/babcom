-- drop table data.connections;

create table data.connections(
  client_id text not null,
  constraint connections_pk primary key(client_id)
);
