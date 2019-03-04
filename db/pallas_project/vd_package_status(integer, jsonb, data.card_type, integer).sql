-- drop function pallas_project.vd_package_status(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_package_status(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case 
  when v_text_value = 'new' then
    return 'Ждёт проверки';
  when v_text_value = 'checking' then
    return 'Проверяется';
  when v_text_value = 'checked' then
    return 'Проверен';
  when v_text_value = 'frozen' then
    return 'Задержан';
  when v_text_value = 'arrested' then
    return 'Арестован';
  when v_text_value = 'received' then
    return 'Выдан';
  when v_text_value = 'future' then
    return 'Будущий';
  else
    return 'Неизвестно';
  end case;
end;
$$
language plpgsql;
