-- drop type types.attribute_type;

create type types.attribute_type as enum(
  'system',
  'hidden',
  'normal');
