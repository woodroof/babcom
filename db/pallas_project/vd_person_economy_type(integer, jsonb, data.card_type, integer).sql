-- drop function pallas_project.vd_person_economy_type(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_person_economy_type(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
begin
  if in_value = jsonb '"un"' then
    return 'ООН — только токены';
  elsif in_value = jsonb '"mcr"' then
    return 'МРК — только текущий счёт';
  elsif in_value = jsonb '"asters"' then
    return 'Астеры — инвестиционный и обнуляемый текущий счета';
  elsif in_value = jsonb '"fixed"' then
    return 'Фиксированные статусы — нет счетов, нет распределения токенов';
  elsif in_value = jsonb '"fixed_with_money"' then
    return 'Фиксированные статусы, есть счёт — нет распределения токенов';
  end if;

  assert false;
end;
$$
language plpgsql;
