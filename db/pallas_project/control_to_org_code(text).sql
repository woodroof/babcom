-- drop function pallas_project.control_to_org_code(text);

create or replace function pallas_project.control_to_org_code(in_control text)
returns text
immutable
as
$$
begin
  if in_control = 'opa' or in_control = 'administration' then
    return 'org_' || in_control;
  elsif in_control = 'opab' then
    return 'org_free_sky';
  end if;

  assert in_control = 'cartel';
  return 'org_starbucks';
end;
$$
language plpgsql;
