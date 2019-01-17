-- drop table data.attribute_values_journal;

create table data.attribute_values_journal(
  id integer not null generated always as identity,
  object_id integer not null,
  attribute_id integer not null,
  value_object_id integer,
  value jsonb,
  start_time timestamp with time zone not null,
  start_reason text,
  start_actor_id integer,
  end_time timestamp with time zone not null,
  end_reason text,
  end_actor_id integer,
  constraint attribute_values_journal_object_check check(data.is_instance(object_id)),
  constraint attribute_values_journal_pk primary key(id)
);
