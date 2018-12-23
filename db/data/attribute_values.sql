-- drop table data.attribute_values;

create table data.attribute_values(
  id integer not null generated always as identity,
  object_id integer not null,
  attribute_id integer not null,
  value_object_id integer,
  value jsonb,
  start_time timestamp with time zone not null default now(),
  start_reason text,
  start_actor_id integer,
  constraint attribute_values_override_check check((value_object_id is null) or data.can_attribute_be_overridden(attribute_id)),
  constraint attribute_values_pk primary key(id)
);

comment on column data.attribute_values.value_object_id is 'Объект, для которого переопределено значение атрибута. В случае, если видно несколько переопределённых значений, выбирается значение для объекта с наивысшим приоритетом.';
