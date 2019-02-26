-- drop function pallas_project.vd_contract_status(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_contract_status(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_status text := json.get_string(in_value);
begin
  assert v_status in ('unconfirmed', 'confirmed', 'active', 'suspended', 'cancelled', 'suspended_cancelled', 'not_active');

  if v_status = 'unconfirmed' then
    return 'Ожидает подтверждения';
  elsif v_status = 'confirmed' then
    return 'Активный со следующего цикла';
  elsif v_status = 'active' then
    return 'Активный';
  elsif v_status = 'suspended' then
    return 'Выплаты по контракту приостановлены';
  elsif v_status = 'cancelled' then
    return 'Отменён со следующего цикла';
  elsif v_status = 'suspended_cancelled' then
    return 'Отменён со следующего цикла, выплаты по контракту приостановлены';
  else
    return 'Отменён';
  end if;
end;
$$
language plpgsql;
