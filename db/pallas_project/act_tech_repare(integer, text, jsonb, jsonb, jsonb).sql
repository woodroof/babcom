-- drop function pallas_project.act_tech_repare(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_tech_repare(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);  
  v_tech_code text := json.get_string(in_params, 'tech_code');
  v_tech_broken text := json.get_string(data.get_attribute_value_for_update(v_tech_code, 'tech_broken'));
  v_tech_skill integer := json.get_integer_opt(data.get_attribute_value_for_share(v_actor_id, 'system_person_tech_skill'), null);
  v_system_person_repare_count jsonb := coalesce(data.get_attribute_value_for_update(v_actor_id, 'system_person_repare_count'), jsonb '{}');
  v_economic_cycle_number integer := data.get_integer_param('economic_cycle_number');
  v_last_cycle_repare integer := json.get_integer_opt(v_system_person_repare_count, 'cycle', 0);
  v_repare_count integer;
  v_is_stimulant_used boolean := json.get_boolean_opt(data.get_attribute_value_for_share(v_actor_id, 'system_person_is_stimulant_used'), false);
  v_total_skill integer;
  v_seconds integer;
  v_message_sent boolean := false;
  v_is_master boolean := pp_utils.is_in_group(v_actor_id, 'master');
begin
  assert in_request_id is not null;
  if v_tech_broken not in ('broken') then 
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Нельзя починить несломанное');
    return;
  end if;
  if v_tech_skill is null and not v_is_master then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Вы не умеете чинить');
    return;
  end if;
  if v_last_cycle_repare = v_economic_cycle_number then
    v_repare_count := json.get_integer(v_system_person_repare_count, 'count');
    if v_repare_count > 2 and not v_is_master then
        perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Вы исчерпали запас запчастей для ремонта в этом цикле');
        return;
    end if;
  end if;

  if v_repare_count is not null then
    v_system_person_repare_count := jsonb_set(v_system_person_repare_count, array['count'], to_jsonb(v_repare_count + 1));
  else
    v_system_person_repare_count := jsonb_build_object('cycle', v_economic_cycle_number, 'count', 1);
  end if;
  perform data.change_object_and_notify(v_actor_id, 
                                        jsonb_build_array(data.attribute_change2jsonb('system_person_repare_count', v_system_person_repare_count)),
                                        v_actor_id);
  v_total_skill := v_tech_skill + (case when v_is_stimulant_used then 1 else 0 end);
  if v_total_skill = 0 then
    v_seconds := 120;
  elsif v_total_skill = 1 then
    v_seconds := 90;
  elsif v_total_skill >=2 then
    v_seconds := 60;
  elsif v_is_master then
    v_total_skill := -100;
    v_seconds := 3;
  end if;
    perform data.create_job(clock_timestamp() + (v_seconds::text || ' seconds')::interval, 
    'pallas_project.job_tech_repare', 
    format('{"tech_code": "%s", "skill": %s}', v_tech_code, v_total_skill)::jsonb);

  v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               data.get_object_id(v_tech_code), 
                                               jsonb_build_array(data.attribute_change2jsonb('tech_broken', jsonb '"reparing"')));
  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
