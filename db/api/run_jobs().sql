-- drop function api.run_jobs();

create or replace function api.run_jobs()
returns void
volatile
security definer
as
$$
declare
  v_function text;
  v_params jsonb;
  v_desired_time timestamp with time zone;
  v_deadlock_count integer := 0;
  v_start_time timestamp with time zone;
begin
  loop
    delete from data.jobs
    where id in (
      select id
      from data.jobs
      where desired_time <= clock_timestamp()
      order by desired_time
      limit 1)
    returning function, params into v_function, v_params;

    if v_function is null then
      exit;
    end if;

    v_start_time := clock_timestamp();

    loop
      begin
        execute format('select %s($1)', v_function)
        using v_params;

        exit;
      exception when deadlock_detected then
        v_deadlock_count := v_deadlock_count + 1;
      when others or assert_failure then
        declare
          v_exception_message text;
          v_exception_call_stack text;
        begin
          get stacked diagnostics
            v_exception_message = message_text,
            v_exception_call_stack = pg_exception_context;

          perform data.log(
            'error',
            format(E'Error: %s\nJob function: %s\nJob params: %s\nCall stack:\n%s', v_exception_message, v_function, v_params, v_exception_call_stack));

          -- При ошибке пропускаем job'у, всё равно увидем её и её параметры в логе и сможем повторить
          exit;
        end;
      end;
    end loop;

    perform data.metric_set_max('max_job_time_ms', extract(milliseconds from clock_timestamp() - v_start_time)::integer);
  end loop;

  select min(desired_time)
  into v_desired_time
  from data.jobs;

  if v_desired_time is not null then
    perform api_utils.create_job_notification(v_desired_time);
  end if;

  if v_deadlock_count > 0 then
    perform data.metric_add('deadlock_count', v_deadlock_count);
  end if;
end;
$$
language plpgsql;
