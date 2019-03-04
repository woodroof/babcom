-- drop function pallas_project.vd_status_prices(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_status_prices(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_status_prices integer[] := json.get_integer_array(in_value);
begin
  assert array_length(v_status_prices, 1) = 3;

  return format('%s %s %s', v_status_prices[1], v_status_prices[2], v_status_prices[3]);
end;
$$
language plpgsql;
