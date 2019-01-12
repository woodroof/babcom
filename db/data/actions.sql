-- drop table data.actions;

create table data.actions(
  id integer not null generated always as identity,
  code text not null,
  function text not null,
  constraint actions_pk primary key(id),
  constraint actions_unique_code unique(code)
);

comment on column data.actions.function is 'Имя функции для выполнения действия. Функция вызывается с параметрами (client_id, request_id, params, user_params). Функция должна либо бросить исключение, либо сгенерировать сообщение клиенту.';
