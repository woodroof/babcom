-- drop function data.change_current_object(integer, text, integer, jsonb);

create or replace function data.change_current_object(in_client_id integer, in_request_id text, in_object_id integer, in_changes jsonb)
returns boolean
volatile
as
$$
-- Функция возвращает, отправляли ли сообщение клиенту in_client_id
-- Если функция вернула false, то скорее всего внешнему коду нужно сгенерировать событие ok или action
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_object_code text := data.get_object_code(in_object_id);
  v_subscription_exists boolean;
  v_diffs jsonb;
  v_diff record;
  v_message_sent boolean := false;
begin
  assert in_client_id is not null;
  assert in_request_id is not null;
  assert in_changes is not null;

  select true
  into v_subscription_exists
  from data.client_subscriptions
  where
    client_id = in_client_id and
    object_id = in_object_id;

  -- Если стреляет этот ассерт, то нам нужно вызывать другую функцию
  assert v_subscription_exists;

  v_diffs := data.change_object(in_object_id, in_changes, v_actor_id);

  for v_diff in
  (
    select
      json.get_integer(value, 'client_id') as client_id,
      json.get_object(value, 'object') as object
    from jsonb_array_elements(v_diffs)
  )
  loop
    if v_diff.client_id = in_client_id then
      assert not v_message_sent;

      v_message_sent := true;

      perform api_utils.create_notification(v_diff.client_id, in_request_id, 'diff', jsonb_build_object('object_id', v_object_code, 'object', v_diff.object));
    else
      perform api_utils.create_notification(v_diff.client_id, null, 'diff', jsonb_build_object('object_id', v_object_code, 'object', v_diff.object));
    end if;
  end loop;

  return v_message_sent;
end;
$$
language 'plpgsql';
