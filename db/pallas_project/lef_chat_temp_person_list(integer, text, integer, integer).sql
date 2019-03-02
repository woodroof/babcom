-- drop function pallas_project.lef_chat_temp_person_list(integer, text, integer, integer);

create or replace function pallas_project.lef_chat_temp_person_list(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_chat_code text := replace(data.get_object_code(in_object_id), '_person_list', '');
  v_chat_id integer := data.get_object_id(v_chat_code);

  v_list_object_code text := data.get_object_code(in_list_object_id);

  v_chats_id integer := data.get_object_id(v_list_object_code || '_chats');
  v_master_chats_id integer := data.get_object_id(v_list_object_code || '_master_chats');

  v_title_attribute_id integer := data.get_attribute_id('title');

  v_chat_is_renamed boolean := json.get_boolean_opt(data.get_attribute_value_for_share(v_chat_id, 'system_chat_is_renamed'), false);
  v_chat_parent_list text := json.get_string_opt(data.get_attribute_value(v_chat_id, 'system_chat_parent_list'), '~');
  v_new_chat_subtitle text := '';
  v_chat_title text;

  v_changes jsonb[];
  v_message_sent boolean;

  v_name record;
  v_names jsonb;
begin
  assert in_request_id is not null;
  assert in_list_object_id is not null;

-- добавляем в группу с рассылкой
  perform data.process_diffs_and_notify(data.change_object_groups(in_list_object_id, array[v_chat_id], array[]::integer[], v_actor_id));

  -- обновляем список текущих персон
  v_names := pallas_project.get_chat_persons(v_chat_id, (v_chat_parent_list <> 'master_chats'));
  for v_name in 
    (select x.name from jsonb_to_recordset(v_names) as x(code text, name jsonb) limit 3) loop 
    v_new_chat_subtitle := v_new_chat_subtitle || ', '|| json.get_string(v_name.name);
   end loop;

  v_new_chat_subtitle := trim(v_new_chat_subtitle, ', ');

  -- Меняем заголовок чата
  v_changes := array[]::jsonb[];
  if not v_chat_is_renamed then 
    v_chat_title := v_new_chat_subtitle;
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_title_attribute_id, to_jsonb(v_chat_title)));
  else
    v_chat_title := json.get_string_opt(data.get_raw_attribute_value_for_update(v_chat_id, v_title_attribute_id), '');
    v_changes := array_append(v_changes, data.attribute_change2jsonb('subtitle', to_jsonb(v_new_chat_subtitle)));
  end if;
  perform data.change_object_and_notify(v_chat_id, 
                                        to_jsonb(v_changes),
                                        null);

-- Добавляем чат в список чатов в начало
  if v_chat_parent_list = 'master_chats' then
    perform pp_utils.list_prepend_and_notify(v_master_chats_id, v_chat_code, null);
  elsif v_chat_parent_list = 'chats' then
    perform pp_utils.list_prepend_and_notify(v_chats_id, v_chat_code, null);
  end if;

  -- отправляем нотификацию, что был добавлен в чат
  perform pp_utils.add_notification(in_list_object_id, 'Вы добавлены в чат ' || v_chat_title, v_chat_id);

-- обновляем объект списка
  v_changes := pallas_project.change_chat_person_list_on_person(
    v_chat_id,
    case when not v_chat_is_renamed then v_chat_title else null end,
    (v_chat_parent_list = 'master_chats'),
    true);

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
