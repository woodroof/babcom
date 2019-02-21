-- drop function pallas_project.vd_district_control(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_district_control(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
begin
  return 'todo: ' || in_value::text; 
end;
$$
language plpgsql;
