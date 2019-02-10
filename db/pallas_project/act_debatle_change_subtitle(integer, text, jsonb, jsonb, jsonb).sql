-- drop function pallas_project.act_debatle_change_subtitle(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_change_subtitle(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_subtitle text := json.get_string_opt(in_user_params, 'subtitle','');
  v_debatle_code text := json.get_string(in_params, 'debatle_code');
  v_debatle_id  integer := data.get_object_id(v_debatle_code);
  v_actor_id  integer := data.get_active_actor_id(in_client_id);

  v_message_sent boolean := false;
  v_subtitle_attribute_id integer := data.get_attribute_id('subtitle');
begin
  assert in_request_id is not null;

  perform * from data.objects o where o.id = v_debatle_id for update;
  if coalesce(data.get_raw_attribute_value(v_debatle_id, v_subtitle_attribute_id, null), jsonb '"~~~"') <> to_jsonb(v_subtitle) then
    v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_debatle_id, 
                                               jsonb_build_array(data.attribute_change2jsonb(v_subtitle_attribute_id, to_jsonb(v_subtitle))));
  end if;
  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language plpgsql;
