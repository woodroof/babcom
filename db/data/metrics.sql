-- drop table data.metrics;

create table data.metrics(
  id integer not null generated always as identity,
  type data.metric_type not null,
  value integer not null,
  constraint metrics_pk primary key(id),
  constraint metrics_unique_type unique(type)
);
