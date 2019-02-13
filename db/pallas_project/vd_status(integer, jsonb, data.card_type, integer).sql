-- drop function pallas_project.vd_status(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_status(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_status integer := json.get_integer(in_value);
begin
  assert v_status in (0, 1, 2, 3);

  if v_status = 0 then
    return 'Нет';
  elsif v_status = 1 then
    return 'Бронзовый';
  elsif v_status = 2 then
    return 'Серебряный';
  else
    return 'Золотой';
  end if;
end;
$$
language plpgsql;
