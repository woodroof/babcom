-- drop function pallas_project.act_debatle_change_theme(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_change_theme(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_title text := json.get_string_opt(in_user_params, 'title','');
  v_debatle_code text := json.get_string(in_params, 'debaltle_code');
  v_debatle_id  integer := data.get_object_id(v_debatle_code);
  v_debatle_status text := json.get_string(data.get_attribute_value(v_debatle_id,'debatle_status'));
  v_system_debatle_person1 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person1'), -1);

  v_actor_id  integer := data.get_active_actor_id(in_client_id);
  v_is_master boolean := pallas_project.is_in_group(v_actor_id, 'master');
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

  perform data.change_object(v_debatle_id, 
                             jsonb_build_array(data.attribute_change2jsonb('system_debatle_theme', v_actor_id, to_jsonb(v_title))),
                             v_actor_id);

  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'action',
    format('{"action": "open_object", "action_data": {"object_id": "%s"}}', v_debatle_code)::jsonb);
end;
$$
language 'plpgsql';
