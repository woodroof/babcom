-- drop function pallas_project.vd_status_shop_cycle(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_status_shop_cycle(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
begin
  return 'На цикл ' || json.get_integer(in_value) + 1;
end;
$$
language plpgsql;
