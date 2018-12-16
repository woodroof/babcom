-- drop table data.attributes;

create table data.attributes(
  id integer not null generated always as identity,
  code text not null,
  name text,
  description text,
  type data.attribute_type not null,
  card_type data.card_type,
  value_description_function text,
  can_be_overridden boolean not null,
  constraint attributes_pk primary key(id),
  constraint attributes_unique_code unique(code)
);

comment on column data.attributes.card_type is 'Если null, то применимо ко всем типам карточек';
comment on column data.attributes.value_description_function is 'Имя функции из схемы attribute_value_description_functions. Функция вызывается с параметрами (attribute_id, value, actor_id). Параметр actor_id может быть null.';
comment on column data.attributes.can_be_overridden is 'Если false, то значение атрибута не может переопределяться для объектов';
