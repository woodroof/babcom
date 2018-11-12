-- drop table data.connections;

create table data.connections(
  id integer not null generated always as identity,
  client_id text not null,
  constraint connections_pk primary key(id),
  constraint connections_unique_client_id unique(client_id)
);
