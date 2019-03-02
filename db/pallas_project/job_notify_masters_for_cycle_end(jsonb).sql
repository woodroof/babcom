-- drop function pallas_project.job_notify_masters_for_cycle_end(jsonb);

create or replace function pallas_project.job_notify_masters_for_cycle_end(in_params jsonb)
returns void
volatile
as
$$
begin
  if data.get_boolean_param('game_in_progress') then
    perform pallas_project.send_to_master_chat('До конца цикла осталось 15 минут, пора [подводить итоги](babcom:cycle_checklist)!');
  end if;
end;
$$
language plpgsql;
