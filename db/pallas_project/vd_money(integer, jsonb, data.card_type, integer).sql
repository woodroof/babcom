-- drop function pallas_project.vd_money(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_money(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
begin
  return pp_utils.format_money(json.get_bigint(in_value));
end;
$$
language plpgsql;
