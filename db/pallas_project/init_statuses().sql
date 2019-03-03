-- drop function pallas_project.init_statuses();

create or replace function pallas_project.init_statuses()
returns void
volatile
as
$$
begin
  -- Зависимость от стимуляторов a9e4bc61-4e10-4c9e-a7de-d8f61536f657
  perform data.create_job(timestamp with time zone '2019-03-08 14:00:00', 
    'pallas_project.job_med_set_disease_level', 
    jsonb '{"person_code": "a9e4bc61-4e10-4c9e-a7de-d8f61536f657", "disease": "addiction", "level": 1}');

end;
$$
language plpgsql;
