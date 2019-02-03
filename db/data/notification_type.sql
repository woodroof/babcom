-- drop type data.notification_type;

create type data.notification_type as enum(
  'client_message',
  'metric');
