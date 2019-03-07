-- drop table data.client_subscriptions;

create table data.client_subscriptions(
  id integer not null generated always as identity,
  client_id integer not null,
  object_id integer not null,
  data jsonb not null,
  constraint client_subscriptions_pk primary key(id),
  constraint client_subscriptions_unique_object_client unique(object_id, client_id)
);
