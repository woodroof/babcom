-- drop table data.log;

create table data.log(
  id integer not null generated always as identity,
  severity data.severity not null,
  event_time timestamp with time zone not null default clock_timestamp(),
  message text not null,
  actor_id integer,
  constraint log_actor_check check((actor_id is null) or data.is_instance(actor_id)),
  constraint log_pk primary key(id)
);
