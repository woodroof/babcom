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
  v_debatle_person1 text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person1'), null);

  v_actor_id  integer := data.get_active_actor_id(in_client_id);
  v_is_master boolean := pp_utils.is_in_group(v_actor_id, 'master');
  v_message_sent boolean := false;

  v_title_attribute_id integer := data.get_attribute_id('title');
begin
  assert in_request_id is not null;

  if not v_is_master and (v_debatle_status <> 'draft' or v_debatle_person1 <> data.get_object_code(v_actor_id)) then
    perform api_utils.create_show_message_actrion_notification(
      in_client_id,
      in_request_id,
      'Ошибка', 
      'Тему дебатла нельзя изменить на этом этапе'); 
    return;
  end if;

  if coalesce(data.get_raw_attribute_value_for_update(v_debatle_id, v_title_attribute_id), jsonb '"~~~"') <> to_jsonb(v_title) then
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_debatle_id, 
                                                 jsonb_build_array(data.attribute_change2jsonb(v_title_attribute_id, to_jsonb(v_title))));
  end if;
  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
