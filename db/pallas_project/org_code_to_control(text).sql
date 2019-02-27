-- drop function pallas_project.org_code_to_control(text);

create or replace function pallas_project.org_code_to_control(in_org_code text)
returns text
immutable
as
$$
begin
  if in_org_code = 'org_administration' then
    return 'administration';
  elsif in_org_code = 'org_opa' then
    return 'opa';
  end if;

  assert in_org_code = 'org_starbucks';
  return 'cartel';
end;
$$
language plpgsql;
