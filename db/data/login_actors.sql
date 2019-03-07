-- drop table data.login_actors;

create table data.login_actors(
  id integer not null generated always as identity,
  login_id integer not null,
  actor_id integer not null,
  is_main boolean not null default false,
  constraint login_actors_pk primary key(id),
  constraint login_actors_unique_login_actor unique(login_id, actor_id)
);
