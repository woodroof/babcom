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
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_debatle_status text;
  v_system_debatle_person1 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person1'), -1);
  v_system_debatle_person2 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person2'), -1);
  v_system_debatle_judje integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_judge'), -1);
  v_debatle_title text := json.get_string_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_theme'), '');

  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_debatle_temp_person_list_edited_person_attribute_id integer := data.get_attribute_id('debatle_temp_person_list_edited_person');
  v_system_debatle_temp_person_list_debatle_id_attribute_id integer := data.get_attribute_id('system_debatle_temp_person_list_debatle_id');

  v_debatle_temp_person_list_class_id integer := data.get_class_id('debatle_temp_person_list');
  v_content text[];

  v_temp_object_code text;
  v_temp_object_id integer;
begin
  assert in_request_id is not null;

  v_debatle_status := json.get_string_opt(data.get_attribute_value(v_debatle_id, 'debatle_status'), '~~~');
  if v_debatle_status not in ('new', 'future') then
    perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      format('{"action": "show_message", "action_data": {"title": "%s", "message": "%s"}}', 'Ошибка', 'Участников дебатла нельзя изменить на этом этапе')::jsonb); 
    return;
  end if;

  if v_edited_person not in ('instigator', 'opponent', 'judge') then
    perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      format('{"action": "show_message", "action_data": {"title": "%s", "message": "%s"}}', 'Ошибка', 'Непонятно, какую из персон менять. Наверное что-то пошло не так. Обратитесь к мастеру.')::jsonb); 
    return;
  end if;

  -- создаём темповый список персон
  insert into data.objects(class_id) values (v_debatle_temp_person_list_class_id) returning id, code into v_temp_object_id, v_temp_object_code;

  select array_agg(o.code) into v_content
  from data.object_objects oo
    left join data.objects o on o.id = oo.object_id 
  where oo.parent_object_id = data.get_object_id('player')
    and oo.object_id not in (oo.parent_object_id, v_system_debatle_person1, v_system_debatle_person2, v_system_debatle_judje);

  if v_content is null then
   perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      format('{"action": "show_message", "action_data": {"title": "%s", "message": "%s"}}', 'Ошибка', 'Нет подходящих персон для изменения дебатла')::jsonb); 
    return;
  end if;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_temp_object_id, v_title_attribute_id, to_jsonb(format('Изменение дебатла "%s"', v_debatle_title)), v_actor_id),
  (v_temp_object_id, v_is_visible_attribute_id, jsonb 'true', v_actor_id),
  (v_temp_object_id, v_debatle_temp_person_list_edited_person_attribute_id, to_jsonb(v_edited_person), null),
  (v_temp_object_id, v_content_attribute_id, to_jsonb(v_content), null),
  (v_temp_object_id, v_system_debatle_temp_person_list_debatle_id_attribute_id, to_jsonb(v_debatle_id), null);

  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'action',
    format('{"action": "open_object", "action_data": {"object_id": "%s"}}', v_temp_object_code)::jsonb);
end;
$$
language 'plpgsql';
