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
  v_request_id text;
  v_notification_data jsonb;
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
      (case when value ? 'object' then value->'object' else null end) as object,
      (case when value ? 'list_changes' then value->'list_changes' else null end) as list_changes
    from jsonb_array_elements(v_diffs)
  )
  loop
    assert v_diff.object is not null or v_diff.list_changes is not null;

    if v_diff.client_id = in_client_id then
      assert not v_message_sent;

      v_message_sent := true;

      v_request_id := in_request_id;
    else
      v_request_id := null;
    end if;

    v_notification_data := jsonb_build_object('object_id', v_object_code);

    if v_diff.object is not null then
      v_notification_data := v_notification_data || jsonb_build_object('object', v_diff.object);
    end if;

    if v_diff.list_changes is not null then
      v_notification_data := v_notification_data || jsonb_build_object('list_changes', v_diff.list_changes);
    end if;

    perform api_utils.create_notification(v_diff.client_id, v_request_id, 'diff', v_notification_data);
  end loop;

  return v_message_sent;
end;
$$
language plpgsql;
