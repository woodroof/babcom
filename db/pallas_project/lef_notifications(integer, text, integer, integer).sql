-- drop function pallas_project.lef_notifications(integer, text, integer, integer);

create or replace function pallas_project.lef_notifications(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_system_person_notification_count_attr_id integer := data.get_attribute_id('system_person_notification_count');
  v_redirect_object_id integer := json.get_integer_opt(data.get_raw_attribute_value(in_list_object_id, 'redirect'), null);
  v_content_attr_id integer := data.get_attribute_id('content');
  v_notifications_count integer := json.get_integer(data.get_attribute_value_for_update(v_actor_id, v_system_person_notification_count_attr_id)) - 1;
  v_content text[] :=
    array_remove(
      json.get_string_array(data.get_raw_attribute_value_for_update(in_object_id, v_content_attr_id)),
      data.get_object_code(in_list_object_id));
begin
  if v_redirect_object_id is not null then
    perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, data.get_object_code(v_redirect_object_id));
  else
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;

  perform data.set_attribute_value(in_list_object_id, 'is_visible', jsonb 'false', v_actor_id);
  perform data.change_object_and_notify(
    in_object_id,
    jsonb_build_object('content', to_json(v_content)),
    v_actor_id,
    'Open notification');
  perform data.change_object_and_notify(
    v_actor_id,
    jsonb_build_object('system_person_notification_count', v_notifications_count),
    v_actor_id,
    'Open notification');
end;
$$
language plpgsql;
