-- drop function pallas_project.vd_med_drug_category(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_med_drug_category(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'stimulant' then
    return 'Стимулятор';
  when v_text_value = 'superbuff' then
    return 'Супер-баф';
  when v_text_value = 'sleg' then
    return 'Слег';
  when v_text_value = 'rio_vaccine' then
    return 'Сыворотка от вируса Рио Миаморе';
  else
    return 'Неизвестно';
  end case;
end;
$$
language plpgsql;
