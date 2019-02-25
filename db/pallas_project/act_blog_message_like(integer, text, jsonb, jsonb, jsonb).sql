-- drop function pallas_project.act_blog_message_like(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_blog_message_like(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_blog_message_code text := json.get_string(in_params, 'blog_message_code');
  v_like_on_off text := json.get_string(in_params, 'like_on_off');
  v_is_list boolean := json.get_boolean_opt(in_params, 'is_list', false);
  v_blog_message_id integer := data.get_object_id(v_blog_message_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_system_blog_message_like boolean;
  v_new_like boolean;
  v_blog_message_like_count integer;
  v_new_count integer;

  v_system_blog_message_like_attribute_id integer := data.get_attribute_id('system_blog_message_like');
  v_blog_message_like_count_attribute_id integer := data.get_attribute_id('blog_message_like_count');
  v_changes jsonb[];
  v_message_sent boolean := false;
begin
  -- like_on_off: on - нравится, off - больше не нравится
  assert in_request_id is not null;
  assert v_like_on_off in ('on', 'off');

  v_system_blog_message_like := json.get_boolean_opt(data.get_raw_attribute_value_for_update(v_blog_message_id, v_system_blog_message_like_attribute_id, v_actor_id), false);
  v_blog_message_like_count := json.get_integer_opt(data.get_raw_attribute_value_for_update(v_blog_message_id, v_blog_message_like_count_attribute_id), 0);

  if v_like_on_off = 'on' then
    v_new_like := true;
  end if;

  if coalesce(v_new_like, false) <> v_system_blog_message_like then
    v_changes := array[]::jsonb[];
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_system_blog_message_like_attribute_id, to_jsonb(v_new_like), v_actor_id));
    if v_new_like then 
      v_new_count := v_blog_message_like_count + 1;
    else 
      v_new_count := v_blog_message_like_count - 1;
    end if;
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_blog_message_like_count_attribute_id, to_jsonb(v_new_count)));
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
