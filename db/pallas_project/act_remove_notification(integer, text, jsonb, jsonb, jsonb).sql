-- drop function pallas_project.act_remove_notification(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_remove_notification(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_notification_code text := json.get_string(in_params);
  v_notification_id integer := data.get_object_id(v_notification_code);
  v_system_person_notification_count_attr_id integer := data.get_attribute_id('system_person_notification_count');
  v_content_attr_id integer := data.get_attribute_id('content');
  v_notifications_id integer := data.get_object_id('notifications');
  v_notifications_count integer := json.get_integer(data.get_attribute_value_for_update(v_actor_id, v_system_person_notification_count_attr_id)) - 1;
  v_content text[] :=
    array_remove(
      json.get_string_array(data.get_raw_attribute_value_for_update(v_notifications_id, v_content_attr_id, v_actor_id)),
      v_notification_code);
  v_notified boolean;
begin
  perform data.set_attribute_value(v_notification_id, 'is_visible', jsonb 'false', v_actor_id);
  perform data.change_object_and_notify(
    v_actor_id,
    jsonb_build_object('system_person_notification_count', v_notifications_count),
    v_actor_id,
    'Open notification');

  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      v_notifications_id,
      jsonb '[]' || data.attribute_change2jsonb('content', to_jsonb(v_content), v_actor_id),
      'Open notification');
  assert v_notified;
end;
$$
language plpgsql;
