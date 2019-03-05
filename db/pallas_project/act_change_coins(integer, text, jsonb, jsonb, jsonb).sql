-- drop function pallas_project.act_change_coins(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_change_coins(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_params);
  v_object_id integer := data.get_object_id(v_object_code);
  v_coins_diff integer := json.get_integer(in_user_params, 'coins_diff');
  v_coins integer := json.get_integer(data.get_raw_attribute_value_for_update(v_object_id, 'system_person_coin'));
  v_notified boolean;
  v_diff jsonb;
begin
  if v_coins_diff = 0 then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
    return;
  end if;

  v_diff :=
    pallas_project.change_coins(
      v_object_id,
      v_coins + v_coins_diff,
      data.get_active_actor_id(in_client_id),
      'Изменение количества доступных коинов мастером');
  v_notified :=
    data.process_diffs_and_notify_current_object(
      v_diff,
      in_client_id,
      in_request_id,
      v_object_id);
  assert v_notified;
end;
$$
language plpgsql;
