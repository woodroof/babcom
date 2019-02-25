-- drop function pallas_project.act_blog_message_edit(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_blog_message_edit(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_blog_message_code text := json.get_string(in_params, 'blog_message_code');
  v_is_list boolean := json.get_boolean_opt(in_params, 'is_list', false);
  v_title text := json.get_string(in_user_params, 'title');
  v_text text := json.get_string(in_user_params, 'text');
  v_blog_message_id integer := data.get_object_id(v_blog_message_code);
  v_blog_message_chat_id integer := data.get_object_id(v_blog_message_code || '_chat');
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_old_title text;
  v_old_text text;
  v_blog_name text := json.get_string(data.get_raw_attribute_value_for_share(v_blog_message_id, 'blog_name'));
  v_blog_author integer := json.get_integer(data.get_raw_attribute_value_for_share(data.get_object_id(v_blog_name), 'system_blog_author'));
  v_changes jsonb[];
  v_chat_changes jsonb[];

  v_blog_message_text_attribute_id integer := data.get_attribute_id('blog_message_text');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;
  assert v_blog_author = v_actor_id or pp_utils.is_in_group(v_actor_id, 'master');

  v_old_title := json.get_string_opt(data.get_raw_attribute_value_for_update(v_blog_message_id, v_title_attribute_id), '');
  v_old_text := json.get_string_opt(data.get_raw_attribute_value_for_update(v_blog_message_id, v_blog_message_text_attribute_id), '');

  v_changes := array[]::jsonb[];
  v_chat_changes := array[]::jsonb[];
  if v_old_title <> v_title then
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_title_attribute_id, to_jsonb(v_title)));
    v_chat_changes := array_append(v_changes, data.attribute_change2jsonb(v_title_attribute_id, to_jsonb('Обсуждение новости ' || v_title)));
  end if;
  if v_old_text <> v_text then
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_blog_message_text_attribute_id, to_jsonb(v_text)));
  end if;
  if array_length(v_chat_changes, 1) > 0 then
    perform data.change_object_and_notify(v_blog_message_chat_id, to_jsonb(v_chat_changes), v_actor_id);
  end if;

  if array_length(v_changes, 1) > 0 then
    if v_is_list then
      perform data.change_object_and_notify(v_blog_message_id, 
                                            to_jsonb(v_changes),
                                            v_actor_id);

    else
      v_message_sent := data.change_current_object(in_client_id, 
                                                   in_request_id,
                                                   v_blog_message_id, 
                                                   to_jsonb(v_changes));
    end if;
  end if;

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
