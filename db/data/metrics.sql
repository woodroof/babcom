-- drop table data.metrics;

create table data.metrics(
  id integer not null generated always as identity,
  code text not null,
  value integer not null,
  constraint metrics_pk primary key(id),
  constraint metrics_unique_code unique(code)
);
