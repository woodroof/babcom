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

  -- Генетическая болезнь у Лины Ковач
  perform data.create_job(timestamp with time zone '2019-03-08 14:00:00', 
    'pallas_project.job_med_set_disease_level', 
    jsonb '{"person_code": "54e94c45-ce2a-459a-8613-9b75e23d9b68", "disease": "genetic", "level": 5}');

end;
$$
language plpgsql;
