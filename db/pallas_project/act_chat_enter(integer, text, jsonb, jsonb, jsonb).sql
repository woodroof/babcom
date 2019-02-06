-- drop function pallas_project.act_chat_enter(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_chat_enter(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string_opt(in_params, 'object_code', null);
  v_chat_code text := json.get_string_opt(in_params, 'chat_code', null);
  v_goto_chat boolean := json.get_boolean_opt(in_params, 'goto_chat', false);
  v_actor_id integer :=data.get_active_actor_id(in_client_id);
  v_chat_id integer;

  v_name jsonb;
  v_chat_title text := '';

  v_chats_id integer := data.get_object_id('chats');
begin
  assert in_request_id is not null;
  assert v_object_code is not null or v_chat_code is not null;

  if v_object_code is not null then
    v_chat_id  := json.get_integer(data.get_attribute_value(data.get_object_id(v_object_code), 'system_chat_id', v_actor_id));
    v_chat_code := data.get_object_code(v_chat_id);
  elsif v_chat_code is not null then
    v_chat_id := data.get_object_id(v_chat_code);
  end if;

  --Проверяем, может мы уже в этом чате, тогда ничего делать не надо, только перейти
  if not pp_utils.is_in_group(v_actor_id, v_chat_code) then
  -- добавляем в группу с рассылкой
    perform data.process_diffs_and_notify(data.change_object_groups(v_actor_id, array[v_chat_id], array[]::integer[], v_actor_id));

    -- Меняем заголовок чата, если зашёл не мастер
    if not pp_utils.is_in_group(v_actor_id, 'master') then
    -- обновляем список текущих персон
      for v_name in 
        (select * from unnest(pallas_project.get_chat_persons_but_masters(v_chat_id))) loop 
        v_chat_title := v_chat_title || ', '|| json.get_string_opt(v_name, '');
      end loop;

      v_chat_title := trim(v_chat_title, ', ');
      perform * from data.objects where id = v_chat_id for update;
      if v_object_code is not null or v_goto_chat then
        perform data.change_object_and_notify(v_chat_id, 
                                              jsonb_build_array(data.attribute_change2jsonb('title', null, to_jsonb(v_chat_title))),
                                              null);
      else
        -- если мы заходили из самого чата, то надо прислать обновления себе
        perform data.change_current_object(in_client_id, 
                                           in_request_id, 
                                           v_chat_id, 
                                           jsonb_build_array(data.attribute_change2jsonb('title', null, to_jsonb(v_chat_title))));
      end if;
    end if;

  -- Добавляем чат в список чатов в начало
    perform pp_utils.list_prepend_and_notify(v_chats_id, v_chat_code, v_actor_id);
  end if;
  -- Переходим к чату или остаёмся на нём
  if v_object_code is not null or v_goto_chat then
    perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_chat_code);
  else
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;