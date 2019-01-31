-- drop function pallas_project.act_debatle_change_status(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_change_status(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_debatle_code text := json.get_string(in_params, 'debatle_code');
  v_new_status text := json.get_string(in_params, 'new_status');
  v_debatle_id integer := data.get_object_id(v_debatle_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_is_master boolean := pp_utils.is_in_group(v_actor_id, 'master');
  v_master_group_id integer:= data.get_object_id('master'); 

  v_debatle_status text;
  v_system_debatle_person1 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person1'), -1);
  v_system_debatle_person2 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person2'), -1);
  v_system_debatle_judge integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_judge'), -1);

  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');

  v_content text[];
  v_new_content text[];
  v_debatles_draft_id integer := data.get_object_id('debatles_draft');
  v_debatles_new_id integer := data.get_object_id('debatles_new');
  v_debatles_future_id integer := data.get_object_id('debatles_future');
  v_debatles_current_id integer := data.get_object_id('debatles_current');
  v_debatles_closed_id integer := data.get_object_id('debatles_closed');
  v_debatles_deleted_id integer := data.get_object_id('debatles_deleted');

  v_changes jsonb[];
  v_message_sent boolean;
begin
  assert in_request_id is not null;

  v_debatle_status := json.get_string_opt(data.get_attribute_value(v_debatle_id, 'debatle_status'), '~~~');

  if v_new_status = 'new' and v_debatle_status = 'draft' and (v_is_master or v_actor_id = v_system_debatle_person1) then
    -- удаляем из черновиков у автора, добавляем в неподтверждённые мастерам
    perform * from data.objects where id = v_debatles_draft_id for update;
    perform * from data.objects where id = v_debatles_new_id for update;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_draft_id, 'content', v_system_debatle_person1), array[]::text[]);
    v_new_content := array_remove(v_content, v_debatle_code);
    if v_content <> v_new_content then
       perform data.change_object_and_notify(v_debatles_draft_id, 
                                            jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_system_debatle_person1, to_jsonb(v_new_content))),
                                            v_actor_id);
    end if;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_new_id, 'content', v_master_group_id), array[]::text[]);
    v_new_content := array_prepend(v_debatle_code,v_content);
    if v_content <> v_new_content then
     perform data.change_object_and_notify(v_debatles_new_id, 
                                          jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_master_group_id, to_jsonb(v_new_content))),
                                          v_actor_id);
    end if;

  elsif v_new_status = 'future' and v_debatle_status = 'new' and v_is_master then
    if v_system_debatle_person1 =-1 or v_system_debatle_person2 =-1 then
      perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Зачинщик и оппонент дебатла должны быть заполнены');
      return;
    end if;
    -- удаляем из неподтверждённых у мастера, добавляем в будущие мастеру
    perform * from data.objects where id = v_debatles_new_id for update;
    perform * from data.objects where id = v_debatles_future_id for update;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_new_id, 'content', v_master_group_id), array[]::text[]);
    v_new_content := array_remove(v_content, v_debatle_code);
    if v_content <> v_new_content then
       perform data.change_object_and_notify(v_debatles_new_id, 
                                            jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_master_group_id, to_jsonb(v_new_content))),
                                            v_actor_id);
    end if;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_future_id, 'content', v_master_group_id), array[]::text[]);
    v_new_content := array_prepend(v_debatle_code, v_content);
    if v_content <> v_new_content then
     perform data.change_object_and_notify(v_debatles_future_id, 
                                           jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_master_group_id, to_jsonb(v_new_content))),
                                           v_actor_id);
    end if;
     -- TODO тут следовало бы разослать всем причастным весть о грядущем дебатле!!!!!!!!!!!!!!!

  elsif v_new_status = 'vote' and v_debatle_status = 'future' and (v_is_master or v_system_debatle_judge = v_actor_id) then
    if v_system_debatle_judge = -1 or v_system_debatle_person1 =-1 or v_system_debatle_person2 =-1 then
      perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Попросите мастера внести недостающих участников дебатла прежде чем начать');
      return;
    end if;
  -- удаляем из будущих у мастера, добавляем в текущие всем (TODO вообще не совсем всем, а только тем, кто в аудиории дебатла)
    perform * from data.objects where id = v_debatles_future_id for update;
    perform * from data.objects where id = v_debatles_current_id for update;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_future_id, 'content', v_master_group_id), array[]::text[]);
    v_new_content := array_remove(v_content, v_debatle_code);
    if v_content <> v_new_content then
       perform data.change_object_and_notify(v_debatles_future_id, 
                                             jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_master_group_id, to_jsonb(v_new_content))),
                                             v_actor_id);
    end if;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_current_id, 'content', v_actor_id), array[]::text[]);
    v_new_content := array_prepend(v_debatle_code, v_content);
    if v_content <> v_new_content then
     perform data.change_object_and_notify(v_debatles_current_id, 
                                           jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, null, to_jsonb(v_new_content))),
                                           v_actor_id);
    end if;
  elsif v_new_status = 'vote_over' and v_debatle_status = 'vote' and (v_is_master or v_system_debatle_judge = v_actor_id) then
    null; -- не надо переставлять ничего по группам
  elsif v_new_status = 'closed' and v_debatle_status = 'vote_over' and (v_is_master or v_system_debatle_judge = v_actor_id) then
    -- удаляем из текущих у всех, добавляем в завершённые всем (TODO вообще не совсем всем, а только тем, кто в аудиории дебатла)
    perform * from data.objects where id = v_debatles_current_id for update;
    perform * from data.objects where id = v_debatles_closed_id for update;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_current_id, 'content', v_actor_id), array[]::text[]);
    v_new_content := array_remove(v_content, v_debatle_code);
    if v_content <> v_new_content then
       perform data.change_object_and_notify(v_debatles_current_id, 
                                            jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, null, to_jsonb(v_new_content))),
                                            v_actor_id);
    end if;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_closed_id, 'content', v_actor_id), array[]::text[]);
    v_new_content := array_prepend(v_debatle_code, v_content);
    if v_content <> v_new_content then
      perform data.change_object_and_notify(v_debatles_closed_id, 
                                            jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, null, to_jsonb(v_new_content))),
                                            v_actor_id);
    end if;
-- TODO тут возможно надо ещё менять какие-то статусы участникам дебатла

  elsif v_new_status = 'deleted' and (v_is_master or v_system_debatle_judge = v_actor_id) then
    -- удаляем из черновиков у автора
    -- из неподтверждённых у мастера
    -- из будущих у мастера
    -- из текущих у всех
    -- из закрытых у всех
    -- добавляем в закрытые мастеру
    if v_debatle_status = 'draft' then
      perform * from data.objects where id = v_debatles_draft_id for update;
      v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_draft_id, 'content', v_system_debatle_person1), array[]::text[]);
      v_new_content := array_remove(v_content, v_debatle_code);
      if v_content <> v_new_content then
         perform data.change_object_and_notify(v_debatles_draft_id, 
                                              jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_system_debatle_person1, to_jsonb(v_new_content))),
                                              v_actor_id);
      end if;
    end if;
    if v_debatle_status = 'new' then
      perform * from data.objects where id = v_debatles_new_id for update;
      v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_new_id, 'content', v_master_group_id), array[]::text[]);
      v_new_content := array_remove(v_content, v_debatle_code);
      if v_content <> v_new_content then
         perform data.change_object_and_notify(v_debatles_new_id, 
                                              jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_master_group_id, to_jsonb(v_new_content))),
                                              v_actor_id);
      end if;
    end if;
    if v_debatle_status = 'future' then
      perform * from data.objects where id = v_debatles_future_id for update;
      v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_future_id, 'content', v_master_group_id), array[]::text[]);
      v_new_content := array_remove(v_content, v_debatle_code);
      if v_content <> v_new_content then
         perform data.change_object_and_notify(v_debatles_future_id, 
                                              jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_master_group_id, to_jsonb(v_new_content))),
                                              v_actor_id);
      end if;
    end if;
   if v_debatle_status in ('vote', 'vote_over') then
      perform * from data.objects where id = v_debatles_current_id for update;
      v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_current_id, 'content', v_actor_id), array[]::text[]);
      v_new_content := array_remove(v_content, v_debatle_code);
      if v_content <> v_new_content then
         perform data.change_object_and_notify(v_debatles_current_id, 
                                              jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, null, to_jsonb(v_new_content))),
                                              v_actor_id);
      end if;
    end if;
    if v_debatle_status = 'closed' then
      perform * from data.objects where id = v_debatles_closed_id for update;
      v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_closed_id, 'content', v_actor_id), array[]::text[]);
      v_new_content := array_remove(v_content, v_debatle_code);
      if v_content <> v_new_content then
         perform data.change_object_and_notify(v_debatles_closed_id, 
                                              jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, null, to_jsonb(v_new_content))),
                                              v_actor_id);
      end if;
    end if;
    perform * from data.objects where id = v_debatles_deleted_id for update;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_deleted_id, 'content', v_master_group_id), array[]::text[]);
    v_new_content := array_prepend(v_debatle_code, v_content);
    if v_content <> v_new_content then
      perform data.change_object_and_notify(v_debatles_deleted_id, 
                                            jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_master_group_id, to_jsonb(v_new_content))),
                                            v_actor_id);
    end if;

  else
     perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      format('{"action": "show_message", "action_data": {"title": "%s", "message": "%s"}}', 'Ошибка', 'Некорректное изменение статуса дебатла')::jsonb); 
    return;
  end if;

  perform * from data.objects where id = v_debatle_id for update;

  -- если статус поменялся на future, то надо добавить видимость второму участнику и судье
  -- если статус поменялся на vote, то добавить видимость все
  if v_new_status = 'future' then
    if v_system_debatle_person2 <> -1 then 
     v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', v_system_debatle_person2, jsonb 'true'));
    end if;
    if v_system_debatle_judge <> -1 then 
     v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', v_system_debatle_judge, jsonb 'true'));
    end if;
  elsif v_new_status = 'vote' then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', null, jsonb 'true'));
  end if;
  v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_status', null, to_jsonb(v_new_status)));
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               v_debatle_id, 
                                               to_jsonb(v_changes));
  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language plpgsql;
