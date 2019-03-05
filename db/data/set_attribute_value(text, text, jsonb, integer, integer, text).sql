-- drop function data.set_attribute_value(text, text, jsonb, integer, integer, text);

create or replace function data.set_attribute_value(in_object_code text, in_attribute_code text, in_value jsonb, in_value_object_id integer default null::integer, in_actor_id integer default null::integer, in_reason text default null::text)
returns void
volatile
as
$$
-- Как правило вместо этой функции следует вызывать data.change_object
-- Эта функция не проставляет правильно блокировки и не рассылает уведомлений
begin
  perform data.set_attribute_value(data.get_object_id(in_object_code), data.get_attribute_id(in_attribute_code), in_value, in_value_object_id, in_actor_id, in_reason);
end;
$$
language plpgsql;
