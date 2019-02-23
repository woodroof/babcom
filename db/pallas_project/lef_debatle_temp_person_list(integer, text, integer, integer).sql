-- drop function pallas_project.lef_debatle_temp_person_list(integer, text, integer, integer);

create or replace function pallas_project.lef_debatle_temp_person_list(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_edited_person text := json.get_string(data.get_attribute_value_for_share(in_object_id, 'debatle_temp_person_list_edited_person'));
  v_debatle_id integer := json.get_integer(data.get_attribute_value_for_share(in_object_id, 'system_debatle_temp_person_list_debatle_id'));
  v_debatle_code text := data.get_object_code(v_debatle_id);
  v_list_code text := data.get_object_code(in_list_object_id);

  v_debatle_person1 text := json.get_string_opt(data.get_attribute_value_for_update(v_debatle_id, 'debatle_person1'), null);
  v_debatle_person2 text := json.get_string_opt(data.get_attribute_value(v_debatle_id, 'debatle_person2'), null);
  v_debatle_judge integer := json.get_string_opt(data.get_attribute_value(v_debatle_id, 'debatle_judge'), null);
  v_debatle_status text := json.get_string(data.get_attribute_value(v_debatle_id, 'debatle_status'));

  v_old_person text;
  v_old_person_id integer;

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
    perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Ошибка', 
      'Непонятно, какую из персон менять. Наверное что-то пошло не так. Обратитесь к мастеру.'); 
    return;
  end if;

  if v_edited_person = 'instigator' then
    v_old_person := v_debatle_person1;
    if v_old_person is distinct from v_list_code then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person1', to_jsonb(v_list_code)));
    end if;
  elsif v_edited_person = 'opponent' then
    v_old_person := v_debatle_person2;
    if v_old_person is distinct from v_list_code then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person2', to_jsonb(v_list_code)));
    end if;
  elsif v_edited_person = 'judge' then
    v_old_person := v_debatle_judge;
    if v_old_person is distinct from v_list_code then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_judge', to_jsonb(v_list_code)));
    end if;
  end if;

  v_old_person_id := data.get_object_id_opt(v_old_person);

  if v_old_person_id is not null 
  and v_debatle_status not in ('vote', 'vote_over', 'closed') then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', null, v_old_person_id));
  end if;
  if v_edited_person = 'instigator' 
    or (v_edited_person in ('opponent','judge') and v_debatle_status in ('future', 'vote', 'vote_over', 'closed')) then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', jsonb 'true', in_list_object_id));
  end if;
  perform data.change_object_and_notify(v_debatle_id, to_jsonb(v_changes), v_actor_id);

  if v_old_person_id is not null and v_old_person_id <> in_list_object_id then
    --Удаляем из моих дебатлов у старой персоны,
    perform pp_utils.list_remove_and_notify(v_debatles_my_id, v_debatle_code, v_old_person_id);
  end if;
  -- Добавляем в мои дебатлы новой персоне
  perform pp_utils.list_prepend_and_notify(v_debatles_my_id, v_debatle_code, in_list_object_id);

  perform api_utils.create_go_back_action_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;
