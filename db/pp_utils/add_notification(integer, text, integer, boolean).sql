-- drop function pp_utils.add_notification(integer, text, integer, boolean);

create or replace function pp_utils.add_notification(in_object_id integer, in_text text, in_redirect_object_id integer default null::integer, in_is_important boolean default false)
returns void
volatile
as
$$
declare
  v_notification_code text;
  v_notification_id integer;
  v_redirect_object_code text;
  v_notification_title text;

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_redirect_attribute_id integer := data.get_attribute_id('redirect');
  v_system_person_notification_count_attribute_id integer := data.get_attribute_id('system_person_notification_count');

  v_notifications_id integer := data.get_object_id(data.get_object_code(in_object_id) || '_notifications');
  v_notification_count integer :=
    json.get_integer(data.get_attribute_value_for_update(in_object_id, v_system_person_notification_count_attribute_id)) + 1;
begin
  if in_redirect_object_id is not null then
    v_redirect_object_code := data.get_object_code(in_redirect_object_id);
    v_notification_title := in_text || E'\n\n' || pp_utils.link(v_redirect_object_code);
  else
    v_notification_title := in_text;
  end if;

  -- создаём новый объект для нотификации
  insert into data.objects(class_id) values(data.get_class_id('notification')) returning id, code into v_notification_id, v_notification_code;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_notification_id, v_title_attribute_id, to_jsonb(v_notification_title), null),
  (v_notification_id, v_is_visible_attribute_id, jsonb 'true', in_object_id);
  if in_redirect_object_id is not null then
    insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
    (v_notification_id, v_redirect_attribute_id, to_jsonb(in_redirect_object_id), null);
  end if;

  -- Вставляем в начало списка и рассылаем уведомления
  perform pp_utils.list_prepend_and_notify(v_notifications_id, v_notification_code, null);
  perform data.change_object_and_notify(in_object_id, jsonb '[]' || data.attribute_change2jsonb(v_system_person_notification_count_attribute_id, to_jsonb(v_notification_count)));

  if in_is_important then
    perform pallas_project.send_to_important_notifications(in_object_id, in_text, v_redirect_object_code);
  end if;
end;
$$
language plpgsql;
