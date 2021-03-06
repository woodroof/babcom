-- drop function pallas_project.notify_transfer_sender(integer, bigint);

create or replace function pallas_project.notify_transfer_sender(in_sender_id integer, in_money bigint)
returns void
volatile
as
$$
declare
  v_sender_code text := data.get_object_code(in_sender_id);
  v_type text := json.get_string(data.get_attribute_value(in_sender_id, 'type'));
  v_transactions_id integer := data.get_object_id(v_sender_code || '_transactions');
  v_org_person integer;
  v_org_message text;
begin
  if v_type = 'organization' then
    v_org_message :=
      format(
        'Исходящий перевод со счёта организации [%s](babcom:%s) на сумму %s',
        json.get_string(data.get_attribute_value(in_sender_id, 'title')),
        v_sender_code,
        pp_utils.format_money(in_money));

    for v_org_person in
    (
      select distinct object_id
      from data.object_objects
      where
        parent_object_id in (
          data.get_object_id(v_sender_code || '_head'),
          data.get_object_id(v_sender_code || '_economist'),
          data.get_object_id(v_sender_code || '_auditor'),
          data.get_object_id(v_sender_code || '_temporary_auditor')) and
        object_id != parent_object_id
    )
    loop
      perform pp_utils.add_notification(
        v_org_person,
        v_org_message,
        v_transactions_id);
    end loop;
  else
    assert v_type = 'person';

    perform pp_utils.add_notification(
      in_sender_id,
      format('Списана сумма %s', pp_utils.format_money(in_money)),
      v_transactions_id);
  end if;
end;
$$
language plpgsql;
