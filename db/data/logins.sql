-- drop table data.logins;

create table data.logins(
  id integer not null generated always as identity,
  code text not null,
  constraint logins_pk primary key(id)
);
