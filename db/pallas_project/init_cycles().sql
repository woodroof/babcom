-- drop function pallas_project.init_cycles();

create or replace function pallas_project.init_cycles()
returns void
volatile
as
$$
declare
  v_time timestamp with time zone;
  v_cycle_times timestamp with time zone[] :=
    array[
      timestamp with time zone '2019-03-08 21:00:00',
      timestamp with time zone '2019-03-09 03:00:00',
      timestamp with time zone '2019-03-09 13:00:00',
      timestamp with time zone '2019-03-09 18:00:00',
      timestamp with time zone '2019-03-09 22:00:00',
      timestamp with time zone '2019-03-10 01:00:00'];
begin
  insert into data.params(code, value, description) values
  ('game_in_progress', jsonb 'true', 'Признак того, что игра ещё не закочилась');

  -- Уведомления за час до конца цикла
  for v_time in
  (
    select value - interval '1 hour'
    from unnest(v_cycle_times) a(value)
  )
  loop
    perform data.create_job(v_time, 'pallas_project.job_notify_players_for_cycle_end', null);
  end loop;

  -- Уведомление в мастерский чат за 15 минут до конца цикла
  for v_time in
  (
    select value - interval '15 minute'
    from unnest(v_cycle_times) a(value)
  )
  loop
    perform data.create_job(v_time, 'pallas_project.job_notify_masters_for_cycle_end', null);
  end loop;

  -- Циклы
  for v_time in
  (
    select value
    from unnest(v_cycle_times) a(value)
  )
  loop
    perform data.create_job(v_time, 'pallas_project.job_cycle', null);
  end loop;
end;
$$
language plpgsql;
