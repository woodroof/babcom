-- drop function data.process_diffs_and_notify_current_object(jsonb, integer, text, integer);

create or replace function data.process_diffs_and_notify_current_object(in_diffs jsonb, in_client_id integer, in_request_id text, in_object_id integer)
returns boolean
volatile
as
$$
declare
  v_subscription_exists boolean;
  v_diff record;
  v_object_code text := data.get_object_code(in_object_id);
  v_message_sent boolean := false;
  v_request_id text;
  v_notification_data jsonb;
begin
  assert json.is_object_array(in_diffs);
  assert in_client_id is not null;
  assert in_request_id is not null;

  select true
  into v_subscription_exists
  from data.client_subscriptions
  where
    client_id = in_client_id and
    object_id = in_object_id;

  -- Если стреляет этот ассерт, то нам нужно вызывать другую функцию
  assert v_subscription_exists;

  for v_diff in
  (
    select
      json.get_string(value, 'object_id') as object_id,
      json.get_integer(value, 'client_id') as client_id,
      (case when value ? 'object' then value->'object' else null end) as object,
      (case when value ? 'list_changes' then value->'list_changes' else null end) as list_changes
    from jsonb_array_elements(in_diffs)
  )
  loop
    assert v_diff.object is not null or v_diff.list_changes is not null;

    if v_diff.client_id = in_client_id and v_diff.object_id = v_object_code then
      assert not v_message_sent;

      v_message_sent := true;

      v_request_id := in_request_id;
    else
      v_request_id := null;
    end if;

    v_notification_data := jsonb_build_object('object_id', v_diff.object_id);

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
