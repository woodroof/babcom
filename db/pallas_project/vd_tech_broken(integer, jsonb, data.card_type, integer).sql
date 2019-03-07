-- drop function pallas_project.vd_tech_broken(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_tech_broken(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_value text := json.get_string(in_value);
begin
  case when v_value = 'broken' then
    return 'Сломано';
  when v_value = 'working' then
    return 'Исправно';
  when v_value = 'reparing' then
    return 'Ремонтируется';
  else
    return 'Неизвестно';
  end case;
end;
$$
language plpgsql;
