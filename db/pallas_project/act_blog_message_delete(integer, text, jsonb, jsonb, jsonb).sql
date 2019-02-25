-- drop function pallas_project.act_blog_message_delete(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_blog_message_delete(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_blog_message_code text := json.get_string(in_params, 'blog_message_code');
  v_is_list boolean := json.get_boolean_opt(in_params, 'is_list', false);
  v_blog_message_id integer := data.get_object_id(v_blog_message_code);
  v_blog_message_chat_id integer := data.get_object_id(v_blog_message_code || '_chat');
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_news_id integer := data.get_object_id('news');
  v_blog_name text := json.get_string(data.get_raw_attribute_value_for_share(v_blog_message_id, 'blog_name'));
  v_blog_author integer := json.get_integer(data.get_raw_attribute_value_for_share(data.get_object_id(v_blog_name), 'system_blog_author'));
  v_changes jsonb[];
begin
  assert in_request_id is not null;
  assert v_blog_author = v_actor_id or pp_utils.is_in_group(v_actor_id, 'master');

  v_changes := array[]::jsonb[];
  v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', jsonb 'false'));

  perform data.change_object_and_notify(v_blog_message_id, 
                                        to_jsonb(v_changes),
                                        v_actor_id);

  v_changes := array[]::jsonb[];
  v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', jsonb 'false', v_blog_message_chat_id));

  perform data.change_object_and_notify(v_blog_message_chat_id, 
                                        to_jsonb(v_changes),
                                        v_actor_id);

  if v_is_list then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  else
    perform api_utils.create_go_back_action_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
