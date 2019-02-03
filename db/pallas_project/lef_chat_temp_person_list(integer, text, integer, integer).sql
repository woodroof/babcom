-- drop function pallas_project.lef_chat_temp_person_list(integer, text, integer, integer);

create or replace function pallas_project.lef_chat_temp_person_list(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_chat_id integer := json.get_integer(data.get_attribute_value(in_object_id, 'system_chat_temp_person_list_chat_id'));
  v_chat_code text := data.get_object_code(v_chat_id);

  v_chats_id integer := data.get_object_id('chats');

  v_content_attribute_id integer := data.get_attribute_id('content');
  v_title_attribute_id integer := data.get_attribute_id('title');

  v_chat_title text := '';
  v_person_title text;
  v_chat_subtitle text := json.get_string_opt(data.get_attribute_value(v_chat_id, 'subtitle', v_actor_id), '');

  v_person_code text := data.get_object_code(in_list_object_id);
  v_content text[];
  v_new_content text[];
  v_changes jsonb[];
  v_message_sent boolean;

  v_name jsonb;
  v_persons text := '';
begin
  assert in_request_id is not null;
  assert in_list_object_id is not null;

-- добавляем в группу с рассылкой
  perform data.process_diffs_and_notify(data.change_object_groups(in_list_object_id, array[v_chat_id], array[]::integer[], v_actor_id));

  -- обновляем список текущих персон
  for v_name in 
    (select * from unnest(pallas_project.get_chat_persons_but_masters(v_chat_id))) loop 
    v_persons := v_persons || '
'|| json.get_string_opt(v_name, '');
    v_chat_title := v_chat_title || ', '|| json.get_string_opt(v_name, '');
   end loop;
  v_persons := v_persons || '
'|| '------------------
Кого добавляем?';

  v_chat_title := trim(v_chat_title, ', ');

  -- Меняем заголовок чата
  perform * from data.objects where id = v_chat_id for update;
  perform data.change_object_and_notify(v_chat_id, 
                                        jsonb_build_array(data.attribute_change2jsonb(v_title_attribute_id, null, to_jsonb(v_chat_title))),
                                        null);

-- Добавляем чат в список чатов в начало
  perform pp_utils.list_prepend_and_notify(v_chats_id, v_chat_code, in_list_object_id);

  -- отправляем нотификацию, что был добавлен в чат
  perform pp_utils.add_notification(in_list_object_id, 'Вы добавлены в чат ' || v_chat_subtitle, v_chat_id);

-- удаляем персону из временного списка
  perform * from data.objects where id = in_object_id for update;

  v_content := json.get_string_array_opt(data.get_attribute_value(in_object_id, 'content', v_actor_id), array[]::text[]);
  v_content := array_remove(v_content, v_person_code);

  v_changes := array[]::jsonb[];
  v_changes := array_append(v_changes, data.attribute_change2jsonb('chat_temp_person_list_persons', null, to_jsonb(v_persons)));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('content', null, to_jsonb(v_content)));

  -- рассылаем обновление списка себе
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               in_object_id, 
                                               to_jsonb(v_changes));
  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language plpgsql;
