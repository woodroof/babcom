-- drop function pallas_project.fcard_chat(integer, integer);

create or replace function pallas_project.fcard_chat(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_chat_unread_messages_attribute_id integer := data.get_attribute_id('chat_unread_messages');
begin
  perform data.change_object_and_notify(in_object_id, 
                                        jsonb_build_array(data.attribute_change2jsonb(v_chat_unread_messages_attribute_id, null, in_actor_id)),
                                        in_actor_id);

end;
$$
language plpgsql;
