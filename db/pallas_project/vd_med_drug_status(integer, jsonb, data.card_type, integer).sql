-- drop function pallas_project.vd_med_drug_status(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_med_drug_status(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'not_used' then
    return 'Не использован';
  when v_text_value = 'used' then
    return 'Использован';
  else
    return 'Неизвестно';
  end case;
end;
$$
language plpgsql;
