-- drop function pallas_project.lef_debatle_temp_person_list(integer, text, integer, integer);

create or replace function pallas_project.lef_debatle_temp_person_list(in_client_id integer, in_request_id text, object_id integer, list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_edited_person text := json.get_string(data.get_attribute_value(object_id, 'debatle_temp_person_list_edited_person'));
  v_debatle_id integer := json.get_integer(data.get_attribute_value(object_id, 'system_debatle_temp_person_list_debatle_id'));
  v_changes jsonb[];
begin
  assert in_request_id is not null;

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
    v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person1', null, to_jsonb(list_object_id)));
  elsif v_edited_person = 'opponent' then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person2', null, to_jsonb(list_object_id)));
  elsif v_edited_person = 'judge' then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_judge', null, to_jsonb(list_object_id)));
  end if;

  perform data.change_object_and_notify(v_debatle_id, to_jsonb(v_changes), v_actor_id);

  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'action',
    '{"action": "go_back", "action_data": {}}'::jsonb);
end;
$$
language plpgsql;
