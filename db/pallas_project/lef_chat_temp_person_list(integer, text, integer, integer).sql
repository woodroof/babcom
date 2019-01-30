-- drop function pallas_project.lef_chat_temp_person_list(integer, text, integer, integer);

create or replace function pallas_project.lef_chat_temp_person_list(in_client_id integer, in_request_id text, object_id integer, list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_chat_id integer := json.get_integer(data.get_attribute_value(object_id, 'system_chat_temp_person_list_chat_id'));
  v_chat_code text := data.get_object_code(v_chat_id);

  v_chats_id integer := data.get_object_id('chats');

  v_content_attribute_id integer := data.get_attribute_id('content');

  v_content text[];
  v_new_content text[];
  v_changes jsonb[];
begin
  assert in_request_id is not null;
  assert list_object_id is not null;

  -- добавляем в группу с рассылкой

  -- отправляем нотификацию, что был добавлен в чат
  -- удаляем персону из списка
  -- обновляем список текущих персон
  -- рассылаем обновление списка себе
  -- остаёмся на месте

  perform * from data.objects where id = v_debatle_id for update;

  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'action',
    '{"action": "go_back", "action_data": {}}'::jsonb);
end;
$$
language plpgsql;
