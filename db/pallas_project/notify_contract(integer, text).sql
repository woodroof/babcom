-- drop function pallas_project.notify_contract(integer, text);

create or replace function pallas_project.notify_contract(in_contract_id integer, in_message text)
returns void
volatile
as
$$
declare
  v_contract_person_code text := json.get_string(data.get_attribute_value_for_share(in_contract_id, 'contract_person'));
  v_contract_org_code text := json.get_string(data.get_attribute_value_for_share(in_contract_id, 'contract_org'));
  v_message text := format(E'%s\nОрганизация: %s\nИсполнитель: %s', in_message, pp_utils.link(v_contract_org_code), pp_utils.link(v_contract_person_code));
  v_person_id integer;
begin
  perform pp_utils.add_notification(
    v_contract_person_code,
    v_message,
    in_contract_id,
    true);

  for v_person_id in
  (
    select distinct object_id
    from data.object_objects
    where
      parent_object_id in (data.get_object_id(v_contract_org_code || '_head'), data.get_object_id(v_contract_org_code || '_economist')) and
      object_id != parent_object_id
  )
  loop
    perform pp_utils.add_notification(
      v_person_id,
      v_message,
      in_contract_id,
      true);
  end loop;
end;
$$
language plpgsql;
