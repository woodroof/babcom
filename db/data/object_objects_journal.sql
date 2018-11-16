-- drop table data.object_objects_journal;

create table data.object_objects_journal(
  id integer not null generated always as identity,
  parent_object_id integer not null,
  object_id integer not null,
  intermediate_object_ids integer[],
  start_time timestamp with time zone not null,
  end_time timestamp with time zone not null,
  constraint object_objects_journal_fk_object foreign key(object_id) references data.objects(id),
  constraint object_objects_journal_fk_parent_object foreign key(parent_object_id) references data.objects(id),
  constraint object_objects_journal_pk primary key(id)
);
