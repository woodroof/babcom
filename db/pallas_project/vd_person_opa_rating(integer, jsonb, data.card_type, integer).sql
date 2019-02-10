-- drop function pallas_project.vd_person_opa_rating(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_person_opa_rating(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_rating integer := json.get_integer(in_value);
begin
  assert v_rating > 0;

  if v_rating = 1 then
    return 'чувак не шарит';
  elsif v_rating = 2 then
    return 'чувак малёхо шарит';
  elsif v_rating = 3 then
    return 'чувак шарит, но не впиливает';
  elsif v_rating = 4 then
    return 'чувак конкретно шарит!';
  elsif v_rating = 5 then
    return 'чувак нашарил на респект!';
  elsif v_rating = 6 then
    return 'чуваку весь булыжник респектует!';
  end if;

  return 'летит белталода - респект чуваку!';
end;
$$
language plpgsql;
