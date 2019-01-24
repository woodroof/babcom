-- drop function pallas_project.vd_debatle_temp_bonus_list_person(integer, jsonb, integer);

create or replace function pallas_project.vd_debatle_temp_bonus_list_person(in_attribute_id integer, in_value jsonb, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'instigator' then
    return 'Выберите бонус или штраф для зачинщика дебатла (первый участник) за';
  when v_text_value = 'opponent' then
    return 'Выберите бонус или штраф для опонента (второй участник) за';
  else
    return 'Что-то пошло не так';
  end case;
end;
$$
language plpgsql;
