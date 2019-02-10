-- drop function pallas_project.lef_chats(integer, text, integer, integer);

create or replace function pallas_project.lef_chats(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_chat_code text := data.get_object_code(in_list_object_id);

  v_chat_unread_messages_attribute_id integer := data.get_attribute_id('chat_unread_messages');
begin
  assert in_request_id is not null;
  assert in_list_object_id is not null;

  perform data.change_object_and_notify(in_list_object_id, 
                                        jsonb_build_array(data.attribute_change2jsonb(v_chat_unread_messages_attribute_id, null, v_actor_id)),
                                        v_actor_id);

  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_chat_code);
end;
$$
language plpgsql;
