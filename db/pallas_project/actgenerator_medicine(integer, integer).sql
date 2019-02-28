-- drop function pallas_project.actgenerator_medicine(integer, integer);

create or replace function pallas_project.actgenerator_medicine(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions jsonb := '{}';
begin
  assert in_actor_id is not null;
    v_actions :=
      v_actions ||
      jsonb '{"med_start_patient_reception": 
                {"code": "med_start_patient_reception", 
                 "name": "Начать приём пациента", 
                 "disabled": false, 
                 "params": {}, 
                 "user_params": [{"code": "patient_login", 
                                  "description": "Попросите пациента ввести свой пароль для идентификации", 
                                  "type": "string", 
                                  "restrictions": {"password": true}}]}}';
  return v_actions;
end;
$$
language plpgsql;
