-- drop function api_utils.create_metric_notification(data.metric_type, integer);

create or replace function api_utils.create_metric_notification(in_type data.metric_type, in_value integer)
returns void
volatile
as
$$
declare
  v_notification_code text;
begin
  assert in_type is not null;
  assert in_value is not null;

  insert into data.notifications(type, message)
  values('metric', jsonb_build_object('type', in_type::text, 'value', in_value))
  returning code into v_notification_code;

  perform pg_notify('api_channel', jsonb_build_object('notification_code', v_notification_code)::text);
end;
$$
language plpgsql;
