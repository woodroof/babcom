-- drop function api.get_notification(text);

create or replace function api.get_notification(in_notification_code text)
returns jsonb
volatile
security definer
as
$$
declare
  v_type data.notification_type;
  v_message jsonb;
  v_client_id integer;
  v_client_code text;
  v_ret_val jsonb;
begin
  assert in_notification_code is not null;

  delete from data.notifications
  where code = in_notification_code
  returning type, message, client_id
  into v_type, v_message, v_client_id;

  -- Уведомление могло удалиться из-за отключения клиента
  if v_type is null then
    return null;
  end if;

  if v_client_id is not null then
    select code
    into v_client_code
    from data.clients
    where id = v_client_id;

    assert v_client_code is not null;
  end if;

  v_ret_val :=
    jsonb_build_object(
      'type',
      v_type::text,
      'message',
      v_message);

  if v_client_code is not null then
    v_ret_val := v_ret_val || jsonb_build_object('client_code', v_client_code);
  end if;

  return v_ret_val;
end;
$$
language plpgsql;
