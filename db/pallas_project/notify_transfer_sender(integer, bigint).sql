-- drop function pallas_project.notify_transfer_sender(integer, bigint);

create or replace function pallas_project.notify_transfer_sender(in_sender_id integer, in_money bigint)
returns void
volatile
as
$$
declare
  v_type text := json.get_string(data.get_attribute_value(in_sender_id, 'type', in_sender_id));
begin
  if v_type = 'organization' then
    -- todo
  else
    assert v_type = 'person';

    perform pp_utils.add_notification(
      in_sender_id,
      format('Списана сумма %s', pp_utils.format_money(in_money)),
      data.get_object_id(data.get_object_code(in_sender_id) || '_transactions'));
  end if;
end;
$$
language plpgsql;
