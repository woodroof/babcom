-- drop function pallas_project.act_blog_rename(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_blog_rename(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_blog_code text := json.get_string(in_params, 'blog_code');
  v_title text := json.get_string(in_user_params, 'title');
  v_subtitle text := json.get_string(in_user_params, 'subtitle');
  v_blog_id integer := data.get_object_id(v_blog_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_old_title text;
  v_old_subtitle text;
  v_changes jsonb[];

  v_subtitle_attribute_id integer := data.get_attribute_id('subtitle');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;

  v_old_title := json.get_string_opt(data.get_raw_attribute_value_for_update(v_blog_id, v_title_attribute_id), '');
  v_old_subtitle := json.get_string_opt(data.get_raw_attribute_value_for_update(v_blog_id, v_subtitle_attribute_id), '');

  v_changes := array[]::jsonb[];
  if v_old_title <> v_title then
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_title_attribute_id, to_jsonb(v_title)));
  end if;
  if v_old_subtitle <> v_subtitle then
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_subtitle_attribute_id, to_jsonb(v_subtitle)));
  end if;
  v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_blog_id, 
                                               to_jsonb(v_changes));

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
