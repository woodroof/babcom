-- drop function pallas_project.vd_link(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_link(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
stable
as
$$
begin
  return pp_utils.link(json.get_string(in_value));
end;
$$
language plpgsql;
