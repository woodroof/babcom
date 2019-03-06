-- drop function pallas_project.vd_tech_broken(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_tech_broken(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_value boolean := json.get_boolean(in_value);
begin
  case when v_value then
    return 'Сломано';
  else
    return 'Исправно';
  end case;
end;
$$
language plpgsql;
