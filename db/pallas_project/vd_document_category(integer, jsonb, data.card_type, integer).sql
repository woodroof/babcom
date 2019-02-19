-- drop function pallas_project.vd_document_category(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_document_category(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'private' then
    return '';
  when v_text_value = 'official' then
    return 'Официальный';
  when v_text_value = 'rule' then
    return 'Правило';
  else
    return 'Неизвестно';
  end case;
end;
$$
language plpgsql;
