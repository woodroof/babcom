-- drop function pallas_project.act_debatle_refresh_link(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_refresh_link(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_debatle_code text := json.get_string(in_params, 'debatle_code');
  v_debatle_id integer := data.get_object_id(v_debatle_code);
  v_master_id integer := data.get_object_id('master');

  v_system_debatle_confirm_presence_id integer := json.get_integer(data.get_attribute_value_for_share(v_debatle_id, 'system_debatle_confirm_presence_id'));
  v_debatle_confirm_presence_link text := json.get_string(data.get_raw_attribute_value_for_update(v_debatle_id, 'debatle_confirm_presence_link', v_master_id));
  v_new_link text := json.get_string_opt(data.get_param('objects_url'), '') || data.get_object_code(v_system_debatle_confirm_presence_id);

  v_message_sent boolean := false;

begin
  assert in_request_id is not null;

  if v_debatle_confirm_presence_link <> v_new_link then
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_debatle_id, 
                                                 jsonb_build_array(data.attribute_change2jsonb('debatle_confirm_presence_link', to_jsonb(v_new_link))));
  end if;

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
