-- drop function pallas_project.control_to_text(text);

create or replace function pallas_project.control_to_text(in_control text)
returns text
immutable
as
$$
begin
  if in_control = 'opa' then
    return 'СВП';
  elsif in_control = 'administration' then
    return 'Администрация';
  end if;

  assert in_control = 'cartel';
  return 'Картель';
end;
$$
language plpgsql;
