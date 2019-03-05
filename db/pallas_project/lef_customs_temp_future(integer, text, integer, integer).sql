-- drop function pallas_project.lef_customs_temp_future(integer, text, integer, integer);

create or replace function pallas_project.lef_customs_temp_future(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_list_object_code text := data.get_object_code(in_list_object_id);
  v_package_to_attribute_id integer := data.get_attribute_id('package_to');
  v_package_to text;
  v_package_reactions_attribute_id integer := data.get_attribute_id('package_reactions');
  v_package_reactions text[];

  v_content_attribute_id integer := data.get_attribute_id('content');
  v_content text[];

  v_changes jsonb[] := array[]::jsonb[];
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;
  assert in_list_object_id is not null;

  if v_list_object_code not in ('check_life' ,'check_radiation', 'check_metal') then
    v_package_to := json.get_string_opt(data.get_raw_attribute_value_for_update(in_object_id, v_package_to_attribute_id, null), null);

    v_content := json.get_string_array_opt(data.get_raw_attribute_value_for_update(in_object_id, v_content_attribute_id), array[]::text[]);

    v_package_to := v_list_object_code;
    v_content := array_remove(v_content, v_package_to);

    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_package_to_attribute_id, to_jsonb(v_package_to)));
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_content_attribute_id, to_jsonb(v_content)));
  else
    v_list_object_code := replace(v_list_object_code, 'check_', '');
    v_package_reactions := json.get_string_array_opt(data.get_raw_attribute_value_for_update(in_object_id, v_package_reactions_attribute_id), array[]::text[]);
    if array_position(v_package_reactions, v_list_object_code) is not null then
      v_package_reactions := array_remove(v_package_reactions, v_list_object_code);
    else 
      v_package_reactions := array_append(v_package_reactions, v_list_object_code);
    end if;
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_package_reactions_attribute_id, to_jsonb(v_package_reactions)));
  end if;
  -- рассылаем обновление списка себе
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               in_object_id, 
                                               to_jsonb(v_changes));
  if not v_message_sent then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
