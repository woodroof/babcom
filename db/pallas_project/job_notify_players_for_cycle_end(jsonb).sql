-- drop function pallas_project.job_notify_players_for_cycle_end(jsonb);

create or replace function pallas_project.job_notify_players_for_cycle_end(in_params jsonb)
returns void
volatile
as
$$
declare
  v_person_id integer;
begin
  if data.get_boolean_param('game_in_progress') then
    for v_person_id in
    (
      select object_id
      from data.object_objects
      where
        parent_object_id = data.get_object_id('all_person') and
        object_id != parent_object_id
    )
    loop
      perform pp_utils.add_notification(v_person_id, 'До конца цикла остался один час! Не забудьте купить статусы обслуживания.');
    end loop;

    perform pallas_project.send_to_master_chat('До конца цикла остался один час, можно начинать [подводить итоги](babcom:cycle_checklist).');
  end if;
end;
$$
language plpgsql;
