-- drop table data.logins;

create table data.logins(
  id integer not null generated always as identity,
  code text not null default (pgcrypto.gen_random_uuid())::text,
  constraint logins_pk primary key(id),
  constraint logins_unique_code unique(code)
);
