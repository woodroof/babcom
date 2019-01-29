-- drop table data.client_subscription_objects;

create table data.client_subscription_objects(
  id integer not null generated always as identity,
  client_subscription_id integer not null,
  object_id integer not null,
  index integer not null,
  is_visible boolean not null,
  constraint client_subscription_objects_index_check check(index > 0),
  constraint client_subscription_objects_object_check check(data.is_instance(object_id)),
  constraint client_subscription_objects_pk primary key(id),
  constraint client_subscription_objects_unique_csi_i unique(client_subscription_id, index) deferrable,
  constraint client_subscription_objects_unique_oi_csi unique(object_id, client_subscription_id)
);
