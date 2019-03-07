-- drop function pallas_project.act_notify_everyone(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_notify_everyone(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_message text := json.get_string(in_user_params, 'message');
  v_notification_code text;
  v_notification_id integer;
  v_notification_jsonb jsonb;

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_system_person_notification_count_attribute_id integer := data.get_attribute_id('system_person_notification_count');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');

  v_changes jsonb := jsonb '[]';
  v_notif_changes jsonb := jsonb '[]';
  v_person record;
begin
  if v_message <> '' then
    insert into data.objects(class_id)
    values(data.get_class_id('notification'))
    returning id, code into v_notification_id, v_notification_code;

    v_notification_jsonb := to_jsonb(v_notification_code);

    insert into data.attribute_values(object_id, attribute_id, value, value_object_id)
    values(v_notification_id, v_title_attribute_id, to_jsonb(v_message), null);

    for v_person in
    (
      select
        o.id,
        o.code,
        data.get_raw_attribute_value_for_update(o.id, v_system_person_notification_count_attribute_id) as nc,
        n.id as n_id,
        data.get_raw_attribute_value_for_update(n.id, v_content_attribute_id) as content
      from data.object_objects oo
      join data.objects o on
        o.id = oo.object_id
      join data.objects n on
        n.code = o.code || '_notifications'
      where
        parent_object_id = data.get_object_id('all_person') and
        object_id != parent_object_id
    )
    loop
      v_changes :=
        v_changes ||
        jsonb_build_object(
          'id',
          v_person.id,
          'changes',
          jsonb '[]' ||
          data.attribute_change2jsonb(v_system_person_notification_count_attribute_id, to_jsonb(json.get_integer(v_person.nc) + 1)));
      v_changes :=
        v_changes ||
        jsonb_build_object(
          'id',
          v_person.n_id,
          'changes',
          jsonb '[]' ||
          data.attribute_change2jsonb(v_content_attribute_id, v_notification_jsonb || v_person.content));
      v_notif_changes :=
        v_notif_changes ||
        data.attribute_change2jsonb(v_is_visible_attribute_id, jsonb 'true', v_person.id);
    end loop;

    v_changes :=
      v_changes ||
      jsonb_build_object(
        'id',
        v_notification_id,
        'changes',
        v_notif_changes);

    perform data.process_diffs_and_notify(data.change_objects(v_changes));

    perform pallas_project.send_to_master_chat(v_message);
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
