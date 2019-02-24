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
begin
  assert in_notification_code is not null;

  delete from data.notifications
  where code = in_notification_code
  returning type, message
  into v_type, v_message;

  -- Уведомление могло удалиться из-за отключения клиента
  if v_type is null then
    return null;
  end if;

  return
    jsonb_build_object(
      'type',
      v_type::text,
      'message',
      v_message);
end;
$$
language plpgsql;
