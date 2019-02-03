-- drop function pallas_project.act_chat_rename(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_chat_rename(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_chat_code text := json.get_string(in_params, 'chat_code');
  v_subtitle text := json.get_string(in_user_params, 'subtitle');
  v_chat_id integer := data.get_object_id(v_chat_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_old_subtitle text;

  v_subtitle_attribute_id integer := data.get_attribute_id('subtitle');
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;

  perform * from data.objects where id = v_chat_id for update;

  v_old_subtitle := json.get_string_opt(data.get_attribute_value(v_chat_id, v_subtitle_attribute_id, v_actor_id), '');

  if v_old_subtitle <> v_subtitle then
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_chat_id, 
                                                 jsonb_build_array(data.attribute_change2jsonb(v_subtitle_attribute_id, null, to_jsonb(v_subtitle))));
  end if;
  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language plpgsql;
