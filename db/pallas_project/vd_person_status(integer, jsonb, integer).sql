-- drop function pallas_project.vd_person_status(integer, jsonb, integer);

create or replace function pallas_project.vd_person_status(in_attribute_id integer, in_value jsonb, in_actor_id integer)
returns text
immutable
as
$$
begin
  if in_value = jsonb '0' then
    return 'нет';
  elsif in_value = jsonb '1' then
    return 'бронзовый';
  elsif in_value = jsonb '2' then
    return 'серебряный';
  elsif in_value = jsonb '3' then
    return 'золотой';
  end if;

  assert false;
end;
$$
language plpgsql;
