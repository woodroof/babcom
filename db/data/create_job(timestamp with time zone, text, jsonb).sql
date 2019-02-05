-- drop function data.create_job(timestamp with time zone, text, jsonb);

create or replace function data.create_job(in_desired_time timestamp with time zone, in_function text, in_params jsonb)
returns void
volatile
as
$$
declare
  v_min_time timestamp with time zone;
begin
  assert in_desired_time is not null;
  assert in_function is not null;

  insert into data.jobs(desired_time, function, params)
  values(in_desired_time, in_function, in_params);

  select min(desired_time)
  into v_min_time
  from data.jobs;

  if v_min_time = in_desired_time then
    perform api_utils.create_job_notification(in_desired_time);
  end if;
end;
$$
language plpgsql;
