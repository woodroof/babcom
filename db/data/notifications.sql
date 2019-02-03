-- drop table data.notifications;

create table data.notifications(
  id integer not null generated always as identity,
  code text not null default (pgcrypto.gen_random_uuid())::text,
  type data.notification_type not null,
  message jsonb not null,
  client_id integer,
  constraint notifications_client_check check((type = 'client_message'::data.notification_type) = (client_id is not null)),
  constraint notifications_pk primary key(id),
  constraint notifications_unique_code unique(code)
);
