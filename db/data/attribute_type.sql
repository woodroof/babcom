-- drop type data.attribute_type;

create type data.attribute_type as enum(
  'system',
  'hidden',
  'normal');
