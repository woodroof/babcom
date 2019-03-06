-- drop function pp_utils.get_source_resource(text);

create or replace function pp_utils.get_source_resource(in_resource text)
returns text
immutable
as
$$
begin
  if in_resource = 'water' then
    return 'ice';
  elsif in_resource = 'food' then
    return 'foodstuff';
  elsif in_resource = 'medicine' then
    return 'medical_supplies';
  elsif in_resource = 'power' then
    return 'uranium';
  elsif in_resource = 'fuel' then
    return 'methane';
  else
    assert in_resource = 'spare_parts';
    return 'goods';
  end if;
end;
$$
language plpgsql;
