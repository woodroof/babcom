-- drop function pallas_project.vd_lottery_status(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_lottery_status(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
begin
  if in_value = jsonb '"active"' then
    return 'активна';
  elsif in_value = jsonb '"cancelled"' then
    return 'отменена';
  else
    return 'завершена';
  end if;
end;
$$
language plpgsql;
