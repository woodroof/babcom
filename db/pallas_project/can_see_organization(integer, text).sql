-- drop function pallas_project.can_see_organization(integer, text);

create or replace function pallas_project.can_see_organization(in_person_id integer, in_organization_code text)
returns boolean
stable
as
$$
declare
  v_has_read_rights boolean := false;
begin
  select true
  into v_has_read_rights
  where exists (
    select 1
    from data.object_objects
    where
      object_id = in_person_id and
      parent_object_id in (
        data.get_object_id(in_organization_code || '_head'),
        data.get_object_id(in_organization_code || '_economist'),
        data.get_object_id(in_organization_code || '_auditor'),
        data.get_object_id(in_organization_code || '_temporary_auditor')));

  return v_has_read_rights;
end;
$$
language plpgsql;
