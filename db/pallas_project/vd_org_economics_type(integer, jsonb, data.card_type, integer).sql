-- drop function pallas_project.vd_org_economics_type(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_org_economics_type(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_economics_type text := json.get_string(in_value);
begin
  assert v_economics_type in ('normal', 'budget', 'profit');

  if v_economics_type = 'normal' then
    return 'Организация без внешнего дохода';
  elsif v_economics_type = 'budget' then
    return 'Организация, счёт которой дополняется до фиксированного бюджета на цикл';
  else
    return 'Организация, получающая фиксированную сумму в цикл';
  end if;
end;
$$
language plpgsql;
