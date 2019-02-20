-- drop function pallas_project.act_finish_lottery(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_finish_lottery(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_lottery_id integer := data.get_object_id('lottery');
  v_lottery_status text := json.get_string(data.get_attribute_value_for_update(v_lottery_id, 'lottery_status'));
  v_menu_attr integer := json.get_integer(data.get_attribute_value_for_update('menu', 'force_object_diff'));
  v_lottery_owner text := json.get_string_opt(data.get_attribute_value_for_share(in_object_id, 'system_lottery_owner'), null);
  v_notified boolean;
begin
  assert in_request_id is not null;
  assert pp_utils.is_in_group(v_actor_id, 'master') or v_actor_id = data.get_object_id(v_lottery_owner);

  if v_lottery_status = 'active' then
    -- todo: выявление победителя (lock с покупкой билета), перевод его в ООН, уведомление всем жителям Паллады, уведомление победителю
    -- todo: на странице лотереи писать победителя

    v_notified :=
      data.change_current_object(
        in_client_id,
        in_request_id,
        v_lottery_id,
        jsonb '{"lottery_status": "finished"}',
        'Finish lottery action');
    assert v_notified;
    perform data.change_object_and_notify(
      data.get_object_id('menu'),
      jsonb_build_object('force_object_diff', v_menu_attr + 1),
      v_actor_id,
      'Finish lottery action');
    return;
  end if;

  perform api_utils.create_ok_notification(
    in_client_id,
    in_request_id);
end;
$$
language plpgsql;
