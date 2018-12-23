-- drop table data.login_actors;

create table data.login_actors(
  id integer not null generated always as identity,
  login_id integer not null,
  actor_id integer not null,
  priority integer not null,
  constraint login_actors_pk primary key(id)
);

comment on column data.login_actors.priority is 'Приоритет, определяющий порядок следования акторов в списке. Список сортируется по уменьшению приоритета.';
