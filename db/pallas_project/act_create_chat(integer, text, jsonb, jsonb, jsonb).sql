-- drop function pallas_project.act_create_chat(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_create_chat(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_chat_title text := json.get_string_opt(in_params, 'title', null);
  v_chat_is_master boolean := json.get_boolean_opt(in_params, 'chat_is_master', false);
  v_chat_code text;
  v_chat_id integer;
  v_chat_class_id integer := data.get_class_id('chat');

  v_all_chats_id integer := data.get_object_id('all_chats');
  v_master_chats_id integer := data.get_object_id('master_chats');
  v_master_group_id integer := data.get_object_id('master');
begin
  assert in_request_id is not null;

  -- Создаём чат
  v_chat_id := pallas_project.create_chat(v_chat_title, null, null, null, null, v_chat_is_master);
  v_chat_code := data.get_object_code(v_chat_id);

  if v_chat_is_master then
    perform pp_utils.list_prepend_and_notify(v_master_chats_id, v_chat_code, v_master_group_id);
  else
    perform pp_utils.list_prepend_and_notify(v_all_chats_id, v_chat_code, v_master_group_id);
  end if;

  -- Заходим в чат
  perform pallas_project.act_chat_enter(in_client_id, in_request_id, jsonb_build_object('chat_code', v_chat_code, 'goto_chat', true), null, null);

end;
$$
language plpgsql;
