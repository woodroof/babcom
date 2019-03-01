-- drop function pallas_project.vd_med_drug_effect(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_med_drug_effect(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'stimulant' then
    return 'Позволяет работать более эффективно — повышает уровень квалификации на 1. Время действия — 30 минут. Позволяет астерам игнорировать повышенную силу тяжести.
Вызывает привыкание со 2-5 дозы — зависит от особенностей организма и не прогнозируется.';
  when v_text_value = 'superbuff' then
    return 'В случае лёгкого ранения: позволяет использовать конечность и не чувствовать боли. Работает 5 минут. Затем вам станет сильно хуже, чем могло бы быть при обычном течении болезни.
В случае тяжелого ранения: позволяет не терять сознание после ранения. Вы можете медленно передвигаться и разговаривать, не чувствуете боли. Работает 5 минут. После того, как супер-баф закончит действовать, вы впадёте в кому.';
  when v_text_value = 'sleg' then
    return 'Слег';
  else
    return 'Неизвестно';
  end case;
end;
$$
language plpgsql;
