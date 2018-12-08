-- drop schema attribute_value_description_functions;

create schema attribute_value_description_functions;
comment on schema attribute_value_description_functions is 'Схема для функций с описанием значений аргументов. Функции вызываются с параметрами (user_object_id, attribute_id, value), возвращают строку.';
