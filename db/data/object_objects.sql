-- drop table data.object_objects;

create table data.object_objects(
  id integer not null,
  parent_object_id integer not null,
  object_id integer not null,
  intermediate_object_ids integer[],
  start_time timestamp with time zone not null default now(),
  constraint object_objects_intermediate_object_ids_check check(intarray.uniq(intarray.sort(intermediate_object_ids)) = intarray.sort(intermediate_object_ids)),
  constraint object_objects_pk primary key(id)
);

comment on column data.object_objects.intermediate_object_ids is 'Список промежуточных объектов, через которые связан дочерний объект с родительским';
