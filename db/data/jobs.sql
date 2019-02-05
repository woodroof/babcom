-- drop table data.jobs;

create table data.jobs(
  id integer not null generated always as identity,
  desired_time timestamp with time zone not null,
  function text not null,
  params jsonb,
  constraint jobs_pk primary key(id)
);
