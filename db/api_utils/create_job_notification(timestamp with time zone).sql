-- drop function api_utils.create_job_notification(timestamp with time zone);

create or replace function api_utils.create_job_notification(in_desired_time timestamp with time zone)
returns void
volatile
as
$$
declare
  v_timeout_sec double precision := greatest(extract(seconds from in_desired_time - clock_timestamp()), 0.);
  v_notification_code text;
begin
  assert in_desired_time is not null;

  insert into data.notifications(type, message)
  values('job', to_jsonb(v_timeout_sec))
  returning code into v_notification_code;

  perform pg_notify('api_channel', jsonb_build_object('notification_code', v_notification_code)::text);
end;
$$
language plpgsql;
