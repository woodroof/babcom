-- drop function pallas_project.job_cycle(jsonb);

create or replace function pallas_project.job_cycle(in_params jsonb)
returns void
volatile
as
$$
begin
  if not data.get_boolean_param('game_in_progress') then
    return;
  end if;

  -- todo
end;
$$
language plpgsql;
