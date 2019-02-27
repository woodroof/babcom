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
begin
  perform pp_utils.add_notification(
    v_contract_person_code,
    v_message,
    in_contract_id,
    true);

  perform pallas_project.notify_organization(data.get_object_id(v_contract_org_code), v_message, in_contract_id);
end;
$$
language plpgsql;
