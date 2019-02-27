-- drop function pallas_project.job_med_set_disease_level(jsonb);

create or replace function pallas_project.job_med_set_disease_level(in_params jsonb)
returns void
volatile
as
$$
declare
begin
  perform pallas_project.act_med_set_disease_level(null, null, in_params, null, null);
end;
$$
language plpgsql;
