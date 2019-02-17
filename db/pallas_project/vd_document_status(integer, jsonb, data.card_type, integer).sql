-- drop function pallas_project.vd_document_status(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_document_status(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'draft' then
    return 'Редактируется';
  when v_text_value = 'signing' then
    return 'Отправлен на подпись';
  when v_text_value = 'signed' then
    return 'Подписан';
  when v_text_value = 'deleted' then
    return 'Удалён';
  else
    return 'Неизвестно';
  end case;
end;
$$
language plpgsql;
