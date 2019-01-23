-- drop function pallas_project.act_debatle_change_theme(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_change_theme(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_title text := json.get_string_opt(in_user_params, 'title','');
  v_debatle_code text := json.get_string(in_params, 'debatle_code');
  v_debatle_id  integer := data.get_object_id(v_debatle_code);
  v_debatle_status text := json.get_string(data.get_attribute_value(v_debatle_id,'debatle_status'));
  v_system_debatle_person1 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person1'), -1);

  v_actor_id  integer := data.get_active_actor_id(in_client_id);
  v_is_master boolean := pallas_project.is_in_group(v_actor_id, 'master');
  v_message_sent boolean := false;
  v_system_debatle_theme_attribute_id integer := data.get_attribute_id('system_debatle_theme');
begin
  assert in_request_id is not null;

  if v_title = '' then
    perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      format('{"action": "show_message", "action_data": {"title": "%s", "message": "%s"}}', 'Ошибка', 'Нельзя изменить тему на пустую')::jsonb); 
    return;
  end if;

  if not v_is_master and (v_debatle_status <> 'draft' or v_system_debatle_person1 <> v_actor_id) then
    perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      format('{"action": "show_message", "action_data": {"title": "%s", "message": "%s"}}', 'Ошибка', 'Тему дебатла нельзя изменить на этом этапе')::jsonb); 
    return;
  end if;

  perform * from data.objects o where o.id = v_debatle_id for update;
  if coalesce(data.get_raw_attribute_value(v_debatle_id, v_system_debatle_theme_attribute_id, null), jsonb '"~~~"') <> to_jsonb(v_title) then
    v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_debatle_id, 
                                               jsonb_build_array(data.attribute_change2jsonb('system_debatle_theme', null, to_jsonb(v_title))));
  end if;
  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language plpgsql;
