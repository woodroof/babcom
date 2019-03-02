-- drop function pallas_project.touch_notification(integer, integer);

create or replace function pallas_project.touch_notification(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_notification_code text := data.get_object_code(in_object_id);
  v_system_person_notification_count_attr_id integer := data.get_attribute_id('system_person_notification_count');
  v_content_attr_id integer := data.get_attribute_id('content');
  v_notifications_id integer := data.get_object_id(data.get_object_code(in_actor_id) || '_notifications');
  v_notifications_count integer := json.get_integer(data.get_attribute_value_for_update(in_actor_id, v_system_person_notification_count_attr_id)) - 1;
  v_content text[] :=
    array_remove(
      json.get_string_array(data.get_raw_attribute_value_for_update(v_notifications_id, v_content_attr_id)),
      v_notification_code);
begin
  perform data.set_attribute_value(in_object_id, 'is_visible', jsonb 'false', in_actor_id);
  perform data.change_object_and_notify(
    in_actor_id,
    jsonb_build_object('system_person_notification_count', v_notifications_count),
    in_actor_id,
    'Touch notification');
  perform data.change_object_and_notify(
    v_notifications_id,
    jsonb '[]' || data.attribute_change2jsonb('content', to_jsonb(v_content)),
    in_actor_id,
    'Touch notification');
end;
$$
language plpgsql;
