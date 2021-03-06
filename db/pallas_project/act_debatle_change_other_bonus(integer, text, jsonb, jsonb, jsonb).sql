-- drop function pallas_project.act_debatle_change_other_bonus(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_change_other_bonus(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_debatle_change_code text := json.get_string(in_params, 'debatle_change_code');
  v_judged_person text := json.get_string_opt(in_params, 'judged_person', '~~~');
  v_bonus_or_fine text := json.get_string_opt(in_params, 'bonus_or_fine', '~~~');

  v_bonus_reason text := json.get_string_opt(in_user_params, 'bonus_reason', '~~~');
  v_votes integer := json.get_integer_opt(in_user_params, 'votes', 1);

  v_debatle_change_id integer := data.get_object_id(v_debatle_change_code);
  v_debatle_id integer := json.get_integer(data.get_attribute_value(v_debatle_change_id,'system_debatle_id'));
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_debatle_person_bonuses jsonb;
  v_system_debatle_person1_votes integer;
  v_system_debatle_person2_votes integer;
  v_person1 text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person1'), null);
  v_person2 text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person2'), null);

  v_changes jsonb[];
  v_message_sent boolean;
begin
  assert in_request_id is not null;
  assert v_bonus_or_fine in ('bonus', 'fine');

  if v_bonus_or_fine = 'fine' then
    v_votes := (@ v_votes) *(-1);
  end if;

  if v_judged_person not in ('instigator', 'opponent') or v_person1 is null or v_person2 is null then
    perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Ошибка',
      'Непонятно, какой из персон начислять бонусы и штрафы. Наверное что-то пошло не так. Обратитесь к мастеру.');
    return;
  end if;

  if v_judged_person = 'instigator' then
    v_debatle_person_bonuses := coalesce(data.get_attribute_value_for_update(v_debatle_id, 'debatle_person1_bonuses'), jsonb '[]');
    v_debatle_person_bonuses := jsonb_insert(v_debatle_person_bonuses, '{1}', jsonb_build_object('code', 'other', 'name', v_bonus_reason, 'votes', v_votes));
    v_system_debatle_person1_votes := json.get_integer_opt(data.get_attribute_value_for_share(v_debatle_id, 'system_debatle_person1_votes'), 0);  
    v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person1_bonuses', v_debatle_person_bonuses));
    v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person1_votes', 
      to_jsonb(pallas_project.get_debatle_person_votes_text(v_person1, v_system_debatle_person1_votes, v_debatle_person_bonuses))));
  elsif v_judged_person = 'opponent' then
    v_debatle_person_bonuses := coalesce(data.get_attribute_value_for_update(v_debatle_id, 'debatle_person2_bonuses'), jsonb '[]');
    v_debatle_person_bonuses := jsonb_insert(v_debatle_person_bonuses, '{1}', jsonb_build_object('code', 'other', 'name', v_bonus_reason, 'votes', v_votes));
    v_system_debatle_person2_votes := json.get_integer_opt(data.get_attribute_value_for_share(v_debatle_id, 'system_debatle_person2_votes'), 0);
    v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person2_bonuses', v_debatle_person_bonuses));
    v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person2_votes', 
      to_jsonb(pallas_project.get_debatle_person_votes_text(v_person2, v_system_debatle_person2_votes, v_debatle_person_bonuses))));
  end if;

  perform data.change_object_and_notify(v_debatle_id, to_jsonb(v_changes), v_actor_id);

  v_changes := array[]::jsonb[];
  v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_temp_bonus_list_bonuses', v_debatle_person_bonuses));
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               v_debatle_change_id, 
                                               to_jsonb(v_changes));
  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language plpgsql;
