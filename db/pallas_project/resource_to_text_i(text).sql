-- drop function pallas_project.resource_to_text_i(text);

create or replace function pallas_project.resource_to_text_i(in_control text)
returns text
immutable
as
$$
begin
  if in_control = 'water' then
    return 'вода';
  elsif in_control = 'food' then
    return 'еда';
  elsif in_control = 'medicine' then
    return 'лекарства';
  elsif in_control = 'power' then
    return 'электричество';
  elsif in_control = 'fuel' then
    return 'топливо';
  end if;

  assert in_control = 'spare_parts';
  return 'запчасти';
end;
$$
language plpgsql;
