-- drop table data.actions;

create table data.actions(
  id integer not null generated always as identity,
  code text not null,
  function text not null,
  default_params jsonb,
  constraint actions_pk primary key(id),
  constraint actions_unique_code unique(code)
);

comment on column data.actions.function is 'Имя функции для выполнения действия. Функция вызывается с параметрами (client_id, request_id, params, user_params, default_params), где params - параметры, передаваемые на клиент и возвращаемые с него в неизменном виде, user_params - параметры, вводимые пользователем, default_params - параметры, прописанные в данной таблице. Функция должна либо бросить исключение, либо сгенерировать сообщение клиенту.';
