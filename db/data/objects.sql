-- drop table data.objects;

create table data.objects(
  id integer not null generated always as identity,
  code text default (pgcrypto.gen_random_uuid())::text,
  type data.object_type not null default 'instance'::data.object_type,
  class_id integer,
  constraint objects_pk primary key(id),
  constraint objects_unique_code unique(code)
);
