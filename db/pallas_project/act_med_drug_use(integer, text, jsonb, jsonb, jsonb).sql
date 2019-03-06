-- drop function pallas_project.act_med_drug_use(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_med_drug_use(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_med_drug_code text := json.get_string(in_params, 'med_drug_code');
  v_med_drug_id integer := data.get_object_id(v_med_drug_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_actor_code text :=data.get_object_code(v_actor_id);

  v_med_drug_status text := json.get_string_opt(data.get_attribute_value_for_update(v_med_drug_id, 'med_drug_status'), '~~~');
  v_med_drug_category text := json.get_string(data.get_attribute_value(v_med_drug_id, 'med_drug_category'));

  v_changes jsonb[];
  v_message_sent boolean;
begin
  assert in_request_id is not null;

  if v_med_drug_status = 'used' then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Нельзя использовать наркотик повторно');
    return;
  end if;

  case v_med_drug_category 
    when 'stimulant' then 
      perform pallas_project.use_stimulant(v_actor_id);
    when 'superbuff' then
      perform pallas_project.use_superbuff(v_actor_id);
    when 'sleg' then
     perform pallas_project.use_sleg(v_actor_id);
    when 'rio_vaccine' then
     perform pallas_project.use_rio_vaccine(v_actor_id);
    else 
    null;
  end case;

  v_changes := array_append(v_changes, data.attribute_change2jsonb('med_drug_status', jsonb '"used"'));
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               v_med_drug_id, 
                                               to_jsonb(v_changes));
  if not v_message_sent then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
