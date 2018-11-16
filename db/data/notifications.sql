-- drop table data.notifications;

create table data.notifications(
  id integer not null generated always as identity,
  code text not null default (pgcrypto.gen_random_uuid())::text,
  message jsonb not null,
  connection_id integer not null,
  constraint notifications_pk primary key(id),
  constraint notifications_unique_code unique(code)
);
