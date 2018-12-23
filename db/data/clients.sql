-- drop table data.clients;

create table data.clients(
  id integer not null generated always as identity,
  code text not null,
  is_connected boolean not null,
  login_id integer,
  actor_id integer,
  constraint clients_pk primary key(id),
  constraint clients_unique_code unique(code)
);
