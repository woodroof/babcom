-- drop function pallas_project.act_tech_break(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_tech_break(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_tech_code text := json.get_string(in_params, 'tech_code');
  v_tech_id text := replace(v_tech_code, 'equipment_', '');
  v_tech_broken text := data.get_attribute_value_for_update(v_tech_code, 'tech_broken');
  v_message_sent boolean := false;
  v_mine_equipment_id integer := data.get_object_id('mine_equipment');
  v_mine_equipment_json jsonb := data.get_attribute_value_for_update(v_mine_equipment_id, 'mine_equipment');
begin
  assert in_request_id is not null;

  if v_tech_broken = 'broken' then 
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Нельзя сломать уже сломанное');
    return;
  end if;

  if not json.get_boolean_opt(json.get_object_opt(v_mine_equipment_json, v_tech_id, jsonb '{}'), 'broken', true) then
    v_mine_equipment_json := jsonb_set(v_mine_equipment_json, array[v_tech_id, 'broken'], jsonb 'true');
    perform data.change_object_and_notify(v_mine_equipment_id, 
                                           jsonb_build_array(data.attribute_change2jsonb('mine_equipment', v_mine_equipment_json)),
                                           v_actor_id);

    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 data.get_object_id(v_tech_code), 
                                                 jsonb_build_array(data.attribute_change2jsonb('tech_broken', jsonb '"broken"')));
  end if;
  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
