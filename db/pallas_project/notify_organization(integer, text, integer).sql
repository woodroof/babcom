-- drop function pallas_project.notify_organization(integer, text, integer);

create or replace function pallas_project.notify_organization(in_org_id integer, in_message text, in_redirect_id integer)
returns void
volatile
as
$$
declare
  v_org_code text := data.get_object_code(in_org_id);
  v_person_id integer;
begin
  for v_person_id in
  (
    select distinct object_id
    from data.object_objects
    where
      parent_object_id in (data.get_object_id(v_org_code || '_head'), data.get_object_id(v_org_code || '_economist')) and
      object_id != parent_object_id
  )
  loop
    perform pp_utils.add_notification(
      v_person_id,
      in_message,
      in_redirect_id,
      true);
  end loop;
end;
$$
language plpgsql;
