-- drop table data.objects;

create table data.objects(
  id integer not null generated always as identity,
  code text not null default (pgcrypto.gen_random_uuid())::text,
  constraint objects_pk primary key(id),
  constraint objects_unique_code unique(code)
);
