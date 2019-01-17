-- drop type data.object_type;

create type data.object_type as enum(
  'class',
  'instance');
