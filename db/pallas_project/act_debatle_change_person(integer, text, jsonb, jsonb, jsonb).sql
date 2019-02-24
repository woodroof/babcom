-- drop function pallas_project.act_debatle_change_person(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_change_person(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_debatle_code text := json.get_string(in_params, 'debatle_code');
  v_edited_person text := json.get_string_opt(in_params, 'edited_person', '~~~');
  v_debatle_id integer := data.get_object_id(v_debatle_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_title_attribute_id integer := data.get_attribute_id('title');

  v_system_debatle_person1 integer := data.get_object_id_opt(json.get_string_opt(data.get_attribute_value_for_update(v_debatle_id, 'debatle_person1'), null));
  v_system_debatle_person2 integer := data.get_object_id_opt(json.get_string_opt(data.get_attribute_value_for_update(v_debatle_id, 'debatle_person2'), null));
  v_system_debatle_judje integer := data.get_object_id_opt(json.get_string_opt(data.get_attribute_value_for_update(v_debatle_id, 'debatle_judge'), null));
  v_debatle_title text := json.get_string_opt(data.get_raw_attribute_value_for_share(v_debatle_id, v_title_attribute_id), '');

  v_content text[];

  v_temp_object_id integer;
begin
  assert in_request_id is not null;

  if v_edited_person not in ('instigator', 'opponent', 'judge') then
    perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Ошибка', 
      'Непонятно, какую из персон менять. Наверное что-то пошло не так. Обратитесь к мастеру.'); 
    return;
  end if;

  select array_agg(o.code order by av.value) into v_content
  from data.object_objects oo
    left join data.objects o on o.id = oo.object_id
    left join data.attribute_values av on av.object_id = o.id and av.attribute_id = v_title_attribute_id and av.value_object_id is null
  where oo.parent_object_id = data.get_object_id('player')
    and oo.object_id not in (oo.parent_object_id, coalesce(v_system_debatle_person1, -1), coalesce(v_system_debatle_person2, -1), coalesce(v_system_debatle_judje, -1));
  if v_content is null then
    v_content := array[]::text[];
  end if;

  -- создаём темповый список персон
  v_temp_object_id := data.create_object(
  null,
  jsonb_build_array(
    jsonb_build_object('code', 'title', 'value', 'Изменение дебатла "' || v_debatle_title || '"'),
    jsonb_build_object('code', 'is_visible', 'value', true, 'value_object_id', v_actor_id),
    jsonb_build_object('code', 'debatle_temp_person_list_edited_person', 'value', v_edited_person),
    jsonb_build_object('code', 'content', 'value', v_content),
    jsonb_build_object('code', 'system_debatle_id', 'value', v_debatle_id)
  ),
  'debatle_temp_person_list');

  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, data.get_object_code(v_temp_object_id));
end;
$$
language plpgsql;
