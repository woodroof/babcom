-- drop function pallas_project.vd_tech_type(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_tech_type(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'driller' then
    return 'Проходческий щит';
  when v_text_value = 'digger' then
    return 'Бурильная установка';
  when v_text_value = 'buksir' then
    return 'Буксир';
  when v_text_value = 'dron' then
    return 'Дрон';
  when v_text_value = 'loader' then
    return 'Грузовая платформа';
  when v_text_value = 'stealer' then
    return 'Грузовой дрон';
  when v_text_value = 'ship' then
    return 'Корабль';
  when v_text_value = 'train' then
    return 'Вагонетка';
  else
    return 'Оборудование';
  end case;
end;
$$
language plpgsql;
