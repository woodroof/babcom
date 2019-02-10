-- drop function pallas_project.lef_debatle_temp_person_list(integer, text, integer, integer);

create or replace function pallas_project.lef_debatle_temp_person_list(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_edited_person text := json.get_string(data.get_attribute_value(in_object_id, 'debatle_temp_person_list_edited_person'));
  v_debatle_id integer := json.get_integer(data.get_attribute_value(in_object_id, 'system_debatle_temp_person_list_debatle_id'));
  v_debatle_code text := data.get_object_code(v_debatle_id);

  v_system_debatle_person1 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person1'), -1);
  v_system_debatle_person2 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person2'), -1);
  v_system_debatle_judge integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_judge'), -1);
  v_debatle_status text := json.get_string(data.get_attribute_value(v_debatle_id, 'debatle_status'));

  v_old_person integer;

  v_debatles_my_id integer := data.get_object_id('debatles_my');

  v_content_attribute_id integer := data.get_attribute_id('content');

  v_content text[];
  v_new_content text[];
  v_changes jsonb[];

  v_change_debatles_my jsonb[]; 
begin
  assert in_request_id is not null;
  assert in_list_object_id is not null;

  if v_edited_person not in ('instigator', 'opponent', 'judge') then
    perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      format('{"action": "show_message ", "action_data": {"title": "%s", "message": "%s"}}', 'Ошибка', 'Непонятно, какую из персон менять. Наверное что-то пошло не так. Обратитесь к мастеру.')::jsonb); 
    return;
  end if;

  perform * from data.objects where id = v_debatle_id for update;

  if v_edited_person = 'instigator' then
    v_old_person := v_system_debatle_person1;
    if v_old_person <> in_list_object_id then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person1', to_jsonb(in_list_object_id)));
    end if;
  elsif v_edited_person = 'opponent' then
    v_old_person := v_system_debatle_person2;
    if v_old_person <> in_list_object_id then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person2', to_jsonb(in_list_object_id)));
    end if;
  elsif v_edited_person = 'judge' then
    v_old_person := v_system_debatle_judge;
    if v_old_person <> in_list_object_id then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_judge', to_jsonb(in_list_object_id)));
    end if;
  end if;

  -- TODO тут по идее ещё надо проверять, что персона не попадает в аудиторию дебатла, и тогда тоже убирать даже в случае публичных статусов
  if v_old_person <> -1 
  and v_debatle_status not in ('vote', 'vote_over', 'closed') then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', null::jsonb, v_old_person));
  end if;
  if v_edited_person = 'instigator' 
    or (v_edited_person in ('opponent','judge') and v_debatle_status in ('future', 'vote', 'vote_over', 'closed')) then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', jsonb 'true', in_list_object_id));
  end if;
  perform data.change_object_and_notify(v_debatle_id, to_jsonb(v_changes), v_actor_id);

  if v_old_person <> in_list_object_id and v_old_person <> -1 then
    --Удаляем из моих дебатлов у старой персоны,
    perform * from data.objects where id = v_debatles_my_id for update;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_my_id, 'content', v_old_person), array[]::text[]);
    v_new_content := array_remove(v_content, v_debatle_code);
    if v_content <> v_new_content then
      v_change_debatles_my := array_prepend(data.attribute_change2jsonb(v_content_attribute_id, to_jsonb(v_new_content), v_old_person), v_change_debatles_my);
    end if;
  end if;
  -- Добавляем в мои дебатлы новой персоне
  v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_my_id, 'content', in_list_object_id), array[]::text[]);
  v_new_content := array_prepend(v_debatle_code, v_content);
  if v_content <> v_new_content then
    v_change_debatles_my := array_prepend(data.attribute_change2jsonb(v_content_attribute_id, to_jsonb(v_new_content), in_list_object_id), v_change_debatles_my);
  end if;
  if array_length(v_change_debatles_my, 1) > 0 then
    perform data.change_object_and_notify(v_debatles_my_id, 
                                          to_jsonb(v_change_debatles_my),
                                          v_actor_id);
  end if;

  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'action',
    '{"action": "go_back", "action_data": {}}'::jsonb);
end;
$$
language plpgsql;
