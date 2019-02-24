-- drop function pallas_project.act_clear_notifications(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_clear_notifications(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_notifications_id integer := data.get_object_id(data.get_object_code(v_actor_id) || '_notifications');
  v_notified boolean;
begin
  perform data.change_object_and_notify(
    v_actor_id,
    jsonb_build_object('system_person_notification_count', jsonb '0'),
    v_actor_id,
    'Open notification');

  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      v_notifications_id,
      jsonb '[]' || data.attribute_change2jsonb('content', jsonb '[]'),
      'Open notification');

  if not v_notified then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
