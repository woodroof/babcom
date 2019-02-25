-- drop function pallas_project.act_blog_create(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_blog_create(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_title text := json.get_string(in_user_params, 'title');
  v_blog_code text;
  v_blog_id  integer;
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_blog_all_id integer := data.get_object_id('blogs_all');
  v_blog_my_id integer := data.get_object_id('blogs_my');

  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');

begin
  assert in_request_id is not null;

-- создаём новый блог
  v_blog_id := data.create_object(
    null,
    jsonb_build_array(
      jsonb_build_object('code', 'title', 'value', v_title),
      jsonb_build_object('code', 'system_blog_author', 'value', to_jsonb(v_actor_id)),
      jsonb_build_object('code', 'blog_author', 'value', to_jsonb(data.get_object_code(v_actor_id)), 'value_object_code', 'master')
    ),
    'blog');

  v_blog_code := data.get_object_code(v_blog_id);

  -- Добавляем блог в список всех и в список моих для того, кто создаёт
  perform pp_utils.list_prepend_and_notify(v_blog_all_id, v_blog_code, null, v_actor_id);
  perform pp_utils.list_prepend_and_notify(v_blog_my_id, v_blog_code, v_actor_id, v_actor_id);

  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_blog_code);
end;
$$
language plpgsql;
