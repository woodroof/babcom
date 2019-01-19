-- drop function pallas_project.vd_debatle_temp_person_list_edited_person(integer, jsonb, integer);

create or replace function pallas_project.vd_debatle_temp_person_list_edited_person(in_attribute_id integer, in_value jsonb, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'instigator' then
    return 'Выберите зачинщика дебатла';
  when v_text_value = 'opponent' then
    return 'Выберите оппонента для дебатла';
  when v_text_value = 'judge' then
    return 'Выберите судью дебатла';
  when v_text_value = 'vote_over' then
  else
    return 'Что-то пошло не так';
  end case;
end;
$$
language 'plpgsql';
