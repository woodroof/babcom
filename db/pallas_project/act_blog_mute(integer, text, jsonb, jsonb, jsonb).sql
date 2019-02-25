-- drop function pallas_project.act_blog_mute(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_blog_mute(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_blog_code text := json.get_string(in_params, 'blog_code');
  v_mute_on_off text := json.get_string(in_params, 'mute_on_off');
  v_blog_id integer := data.get_object_id(v_blog_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_blog_is_mute boolean;
  v_new_blog_is_mute boolean;

  v_is_master boolean := pp_utils.is_in_group(v_actor_id, 'master');

  v_blog_is_mute_attribute_id integer := data.get_attribute_id('blog_is_mute');
  v_message_sent boolean := false;
begin
  -- mute_on_off: on - заглушить уведомления, off - перестать глушить уведомления
  assert in_request_id is not null;
  assert v_mute_on_off in ('on', 'off');

  v_blog_is_mute := json.get_boolean_opt(data.get_raw_attribute_value_for_update(v_blog_id, v_blog_is_mute_attribute_id, v_actor_id), false);

  if v_mute_on_off = 'on' then
    v_new_blog_is_mute := true;
  end if;

  if coalesce(v_new_blog_is_mute, false) <> v_blog_is_mute then
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_blog_id, 
                                                 jsonb_build_array(data.attribute_change2jsonb(v_blog_is_mute_attribute_id, to_jsonb(v_new_blog_is_mute), v_actor_id)));
  end if;
  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
