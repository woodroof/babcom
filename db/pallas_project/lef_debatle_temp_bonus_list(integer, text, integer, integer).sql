-- drop function pallas_project.lef_debatle_temp_bonus_list(integer, text, integer, integer);

create or replace function pallas_project.lef_debatle_temp_bonus_list(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_judged_person text := json.get_string(data.get_attribute_value(in_object_id, 'debatle_temp_bonus_list_person'));
  v_debatle_id integer := json.get_integer(data.get_attribute_value(in_object_id, 'system_debatle_temp_bonus_list_debatle_id'));
  v_debatle_code text := data.get_object_code(v_debatle_id);

  v_debatle_person_bonuses jsonb;

  v_bonus_code text;
  v_bonus_name text;
  v_bonus_votes integer;

  v_content text[];

  v_changes jsonb[];
  v_message_sent boolean;
begin
  assert in_request_id is not null;
  assert in_list_object_id is not null;

  if v_judged_person not in ('instigator', 'opponent') then
    perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Ошибка',
      'Непонятно, какой из персон начислять бонусы и штрафы. Наверное что-то пошло не так. Обратитесь к мастеру.'); 
    return;
  end if;

  perform * from data.objects where id = v_debatle_id for update;

  v_bonus_code := data.get_object_code(in_list_object_id);
  v_bonus_name := json.get_string_opt(data.get_attribute_value(in_list_object_id, 'title'), '');
  v_bonus_votes := json.get_integer_opt(data.get_attribute_value(in_list_object_id, 'debatle_bonus_votes'), 1);

  if v_judged_person = 'instigator' then
    v_debatle_person_bonuses := coalesce(data.get_attribute_value(v_debatle_id, 'debatle_person1_bonuses'), jsonb '[]');
    v_debatle_person_bonuses := jsonb_insert(v_debatle_person_bonuses, '{1}', jsonb_build_object('code', v_bonus_code, 'name', v_bonus_name, 'votes', v_bonus_votes));
    v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person1_bonuses', v_debatle_person_bonuses));
  elsif v_judged_person = 'opponent' then
    v_debatle_person_bonuses := coalesce(data.get_attribute_value(v_debatle_id, 'debatle_person2_bonuses'), jsonb '[]');
    v_debatle_person_bonuses := jsonb_insert(v_debatle_person_bonuses, '{1}', jsonb_build_object('code', v_bonus_code, 'name', v_bonus_name, 'votes', v_bonus_votes));
    v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person2_bonuses', v_debatle_person_bonuses));
  end if;

  perform data.change_object_and_notify(v_debatle_id, to_jsonb(v_changes), v_actor_id);

  perform * from data.objects where id = in_object_id for update;

  v_content := json.get_string_array_opt(data.get_attribute_value(in_object_id, 'content', v_actor_id), array[]::text[]);
  v_content := array_remove(v_content, v_bonus_code);

  v_changes := array[]::jsonb[];
  v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_temp_bonus_list_bonuses', v_debatle_person_bonuses));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('content', to_jsonb(v_content)));
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
