-- drop function pallas_project.act_customs_package_receive(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_customs_package_receive(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_package_code text := json.get_string(in_params, 'package_code');
  v_list_code text := json.get_string_opt(in_params, 'from_list', null);
  v_receiver_code text := json.get_string(in_user_params, 'receiver_code');
  v_new_status text := 'received';
  v_package_id integer := data.get_object_id(v_package_code);
  v_package_status text := json.get_string(data.get_attribute_value_for_update(v_package_id, 'package_status'));
  v_package_receiver_status integer := json.get_integer(data.get_attribute_value(v_package_id, 'package_receiver_status'));
  v_package_receiver_code text := json.get_string(data.get_attribute_value(v_package_id, 'system_package_receiver_code'));
  v_package_box_code text := json.get_string_opt(data.get_attribute_value(v_package_id, 'system_package_box_code'), null);
  v_package_title text := json.get_string(data.get_attribute_value(v_package_id, 'title'));

  v_message_sent boolean := false;
  v_customs_list_old text;
  v_customs_list_new text;
  v_customs_id integer;
  v_customs_new_id integer;
  v_content text[];
  v_change jsonb[] := array[]::jsonb[];
begin
  if v_package_status <> 'checked' then
    perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Ошибка',
      'Нельзя выдать груз, который не в статусе Проверен'); 
    return;
  end if;
  if v_package_receiver_code <> upper(v_receiver_code) then
    perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Ошибка',
      'Неверный пароль получателя груза'); 
    return;
  end if;

  v_customs_list_old := 'checked';
  v_customs_list_new := 'received';

  v_customs_id := data.get_object_id('customs_' || v_customs_list_old);
  v_customs_new_id := data.get_object_id('customs_' || v_customs_list_new);

  perform pp_utils.list_remove_and_notify(v_customs_id, v_package_code, null);

  v_change := array_append(v_change, data.attribute_change2jsonb('package_status', to_jsonb(v_new_status)));
  v_change := array_append(v_change, data.attribute_change2jsonb('package_box_code', to_jsonb(v_package_box_code)));
  perform data.change_object_and_notify(v_package_id, 
                                          to_jsonb(v_change),
                                          null);

  perform pp_utils.list_prepend_and_notify(v_customs_new_id, v_package_code, null);

  perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Выдача подтверждена',
      'Груз ' || v_package_title || ' находится в коробке ' || coalesce(v_package_box_code, '-') || '. Отдайте коробку получателю.'); 
end;
$$
language plpgsql;
