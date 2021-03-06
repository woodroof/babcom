-- drop function pallas_project.act_chat_rename(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_chat_rename(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_chat_code text := json.get_string(in_params, 'chat_code');
  v_title text := json.get_string(in_user_params, 'title');
  v_chat_id integer := data.get_object_id(v_chat_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_chat_person_list_id integer := data.get_object_id(v_chat_code || '_person_list');
  v_old_title text;
  v_chat_is_renamed boolean;
  v_changes jsonb[];

  v_subtitle_attribute_id integer := data.get_attribute_id('subtitle');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_system_chat_is_renamed_attribute_id integer := data.get_attribute_id('system_chat_is_renamed');
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;

  v_old_title := json.get_string_opt(data.get_raw_attribute_value_for_update(v_chat_id, v_title_attribute_id), '');
  v_chat_is_renamed := json.get_boolean_opt(data.get_attribute_value_for_update(v_chat_id, v_system_chat_is_renamed_attribute_id), false);

  if v_old_title <> v_title then
    v_changes := array[]::jsonb[];
    if not v_chat_is_renamed then
      v_changes := array_append(v_changes, data.attribute_change2jsonb(v_subtitle_attribute_id, to_jsonb(v_old_title)));
      v_changes := array_append(v_changes, data.attribute_change2jsonb(v_system_chat_is_renamed_attribute_id, to_jsonb(true)));
    end if;
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_title_attribute_id, to_jsonb(v_title)));
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_chat_id, 
                                                 to_jsonb(v_changes));

    v_changes := array[]::jsonb[];
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_title_attribute_id, to_jsonb('Участники чата ' || v_title)));
    perform data.change_object_and_notify(v_chat_person_list_id, to_jsonb(v_changes), v_actor_id);
  end if;

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
