-- drop function data.change_current_object(integer, text, integer, jsonb, text);

create or replace function data.change_current_object(in_client_id integer, in_request_id text, in_object_id integer, in_changes jsonb, in_reason text default null::text)
returns boolean
volatile
as
$$
-- Функция возвращает, отправляли ли сообщение клиенту in_client_id
-- Если функция вернула false, то скорее всего внешнему коду нужно сгенерировать событие ok или action
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
begin
  assert in_changes is not null;

  return data.process_diffs_and_notify_current_object(
    data.change_object(in_object_id, in_changes, v_actor_id, in_reason),
    in_client_id,
    in_request_id,
    in_object_id);
end;
$$
language plpgsql;
