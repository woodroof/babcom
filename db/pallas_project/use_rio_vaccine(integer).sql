-- drop function pallas_project.use_rio_vaccine(integer);

create or replace function pallas_project.use_rio_vaccine(in_actor_id integer)
returns void
volatile
as
$$
declare
  v_orig_person_id integer := json.get_integer_opt(data.get_attribute_value(in_actor_id, 'system_person_original_id'), in_actor_id);
  v_orig_person_code text := data.get_object_code(v_orig_person_id);
  v_person_id integer; 

  v_med_health jsonb := coalesce(data.get_attribute_value_for_update(v_orig_person_code || '_med_health', 'med_health'), jsonb '{}');
  v_rio_level integer := json.get_integer_opt(json.get_object_opt(v_med_health, 'rio_miamore', jsonb '{}'), 'level', 0);
begin
  if v_rio_level <> 0 then
    -- Cдвигаем болезнь в 0
    perform pallas_project.act_med_set_disease_level(
      null, 
      null, 
      format('{"person_code": "%s", "disease": "%s", "level": %s}', v_orig_person_code, 'rio_miamore', 0)::jsonb, 
      null, 
      null);

    -- Запускаем процесс выздоровления
    perform pallas_project.act_med_set_disease_level(
      null, 
      null, 
      format('{"person_code": "%s", "disease": "%s", "level": %s}', v_orig_person_code, 'back_rio_miamore', v_rio_level-1)::jsonb, 
      null, 
      null);
  end if;
end;
$$
language plpgsql;
