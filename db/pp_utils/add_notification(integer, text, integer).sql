-- drop function pp_utils.add_notification(integer, text, integer);

create or replace function pp_utils.add_notification(in_actor_id integer, in_text text, in_redirect_object integer default null::integer)
returns void
volatile
as
$$
declare
  v_notification_code text;
  v_notification_id  integer;

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_temporary_object_attribute_id integer := data.get_attribute_id('temporary_object');
  v_redirect_attribute_id integer := data.get_attribute_id('redirect');

  v_notifications_id integer := data.get_object_id('notifications');
begin
  -- создаём новый объект для нотификации
  insert into data.objects default values returning id, code into v_notification_id, v_notification_code;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_notification_id, v_title_attribute_id, to_jsonb(in_text), null),
  (v_notification_id, v_is_visible_attribute_id, jsonb 'true', in_actor_id),
  (v_notification_id, v_temporary_object_attribute_id, jsonb 'true', null),
  (v_notification_id, v_redirect_attribute_id, to_jsonb (in_redirect_object), in_actor_id);

  -- Вставляем в начало списка и рассылаем уведомления
  perform pp_utils.list_prepend_and_notify(v_notifications_id, v_notification_code, in_actor_id);

end;
$$
language plpgsql;
