-- drop function pallas_project.act_med_cure(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_med_cure(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_med_computer_code text := json.get_string(in_params, 'med_computer_code');
  v_person_code text := json.get_string(in_params, 'person_code');
  v_disease text := json.get_string(in_params, 'disease');
  v_message text;
  v_med_clinic_money_price integer := 20;
  v_med_clinic_panacelin_price integer := 1;

  v_clinic_money integer;
  v_resource_panacelin integer;

  v_person_id integer := data.get_object_id(v_person_code);
  v_child_person_id integer;

  v_med_health jsonb;

  v_health_care_status integer;
  v_orig_health_care_status integer;

  v_time_to_next integer;
  v_next_level integer;
  v_job_id integer;

  v_message_sent boolean := false;
  v_changes jsonb[];
  v_diff jsonb;
  v_med_skill integer := json.get_integer_opt(data.get_attribute_value(v_actor_id, 'system_person_med_skill'), null);
  v_is_stimulant boolean := json.get_boolean_opt(data.get_attribute_value(v_actor_id, 'system_person_is_stimulant_used'), null);

  v_med_asthma integer;
begin
  select coalesce(max(json.get_integer_opt(data.get_attribute_value_for_share(x, 'system_person_health_care_status'), 0)), 0) into v_health_care_status 
    from unnest(json.get_integer_array_opt(data.get_attribute_value(v_person_id, 'system_person_doubles_id_list'), array[]::integer[])) as x;
  v_orig_health_care_status := json.get_integer_opt(data.get_attribute_value_for_share(v_person_id, 'system_person_health_care_status'), 0);
  if v_orig_health_care_status > v_health_care_status then
    v_health_care_status := v_orig_health_care_status;
  end if;

  if v_disease in ('addiction', 'sleg_addiction') and v_health_care_status < 3 then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Вылечить не удалось', 'Пациент должен иметь золотой статус медицинского обслуживания, чтобы получить лекарство от наркотической зависимости');
    return;
  end if;

  v_person_id := json.get_integer_opt(data.get_attribute_value(v_person_id, 'system_person_original_id'), v_person_id);
  v_person_code := data.get_object_code(v_person_id);

  v_med_health := coalesce(data.get_attribute_value_for_update(v_person_code || '_med_health', 'med_health'), jsonb '{}');

  if json.get_integer_opt(json.get_object_opt(v_med_health, v_disease, jsonb '{}'), 'level', 0) <> 0 then
    if v_disease = 'wound' then
      if v_med_skill < 1 and not v_is_stimulant then 
        perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Вылечить не удалось', 'У вас недостаточно компетенции, чтобы помочь этому пациенту.');
        return;
      end if;
      if v_health_care_status < 2 then
        case random.random_integer(1,3)
          when 1 then v_message := 'У вас кружится голова, вас знобит, вас мучает жажда. Пройдет через 30 минут.';
          when 2 then v_message := 'Вы чувствуете себя очень слабым. Час не можете бегать, пользоваться оружием и работать.';
          when 3 then v_message := 'Приступы мучительной боли будет преследовать вас ещё час. Вспоминайте раз в 5-7 минут о месте ранения и страдайте.';
          else null;
        end case;
      elsif v_health_care_status < 3 then
        case random.random_integer(1,3)
          when 1 then v_message := 'У вас кружится голова, вас знобит, вас мучает жажда. Пройдет через 15 минут.';
          when 2 then v_message := 'Вы чувствуете себя очень слабым. Полчаса не можете бегать, пользоваться оружием и работать.';
          else v_message := null;
        end case;
      end if;
      perform pallas_project.act_med_set_disease_level(
        null, 
        null, 
        format('{"person_code": "%s", "disease": "%s", "level": %s}', v_person_code, v_disease, 0)::jsonb, 
        null, 
        null);
    elsif v_disease = 'radiation' then
      perform pallas_project.act_med_set_disease_level(
        null, 
        null, 
        format('{"person_code": "%s", "disease": "%s", "level": %s}', v_person_code, v_disease, 0)::jsonb, 
        null, 
        null);
    elsif v_disease = 'asthma' then
      v_med_asthma := json.get_integer_opt(data.get_attribute_value_for_update(v_person_code || '_med_health', 'med_asthma'), 0);
      if v_med_asthma >= 2 then
        perform pallas_project.act_med_set_disease_level(
          null, 
          null, 
          format('{"person_code": "%s", "disease": "%s", "level": %s}', v_person_code, v_disease, 0)::jsonb, 
          null, 
          null);
      else
        perform pallas_project.act_med_set_disease_level(
          null, 
          null, 
          format('{"person_code": "%s", "disease": "%s", "level": %s}', v_person_code, v_disease, 1)::jsonb, 
          null, 
          null);
      end if;
      v_changes := array[]::jsonb[];
      v_changes := array_append(v_changes, data.attribute_change2jsonb('med_asthma', case when v_med_asthma >=2 then null else to_jsonb(v_med_asthma + 1) end));
      perform data.change_object_and_notify(data.get_object_id(v_person_code || '_med_health'), 
                                            to_jsonb(v_changes),
                                            null);
    elsif v_disease = 'addiction' then
      v_med_clinic_money_price := 40;
      v_med_clinic_panacelin_price := 2;
      perform pallas_project.act_med_set_disease_level(
        null, 
        null, 
        format('{"person_code": "%s", "disease": "%s", "level": %s}', v_person_code, v_disease, 0)::jsonb, 
        null, 
        null);
    elsif v_disease = 'sleg_addiction' then
      v_med_clinic_money_price := 40;
      v_med_clinic_panacelin_price := 2;
      perform pallas_project.act_med_set_disease_level(
        null, 
        null, 
        format('{"person_code": "%s", "disease": "%s", "level": %s}', v_person_code, v_disease, 0)::jsonb, 
        null, 
        null);
    end if;

  else
    if v_disease = 'wound' then
      perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Вылечить не удалось', 'Хирургическое вмешательство в данном случае неприменимо.');
        return;
    end if;
    if v_disease in ('addiction','sleg_addiction') then
      v_med_clinic_money_price := 40;
      v_med_clinic_panacelin_price := 2;
    end if;
    v_message := 'Вы чувствуете лёгкую тошноту. Через несколько секунд она пройдёт.';
  end if;

  if coalesce(v_message,'') <> '' then
    perform pp_utils.add_notification(v_person_id, v_message);
    for v_child_person_id in (select * from unnest(json.get_integer_array_opt(data.get_attribute_value(v_person_id, 'system_person_doubles_id_list'), array[]::integer[]))) loop
      perform pp_utils.add_notification(v_child_person_id, v_message);
    end loop;
  end if;

  v_changes := array[]::jsonb[];
  if pp_utils.is_in_group(v_actor_id, 'unofficial_doctor') then
    v_clinic_money := json.get_bigint_opt(data.get_attribute_value('org_clean_asteroid', 'system_money'), 0);
    if v_clinic_money < v_med_clinic_money_price then
      perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Не удалось', 'Недостаточно денег на счёте организации');
      return;
    end if;
    v_diff := pallas_project.change_money(data.get_object_id('org_clean_asteroid'), v_clinic_money - v_med_clinic_money_price, v_actor_id, 'Cure');
    perform pallas_project.create_transaction(
          data.get_object_id('org_clean_asteroid'),
          null,
          'Покупка чистящих средств',
          -v_med_clinic_money_price,
          v_clinic_money - v_med_clinic_money_price,
          null,
          null,
          v_actor_id,
           array[
            data.get_object_id('org_clean_asteroid_head'),
            data.get_object_id('org_clean_asteroid_economist'),
            data.get_object_id('org_clean_asteroid_auditor'),
            data.get_object_id('org_clean_asteroid_temporary_auditor')]);
      perform data.process_diffs_and_notify(v_diff);

  elsif pp_utils.is_in_group(v_actor_id, 'doctor') then
    v_resource_panacelin := json.get_bigint_opt(data.get_attribute_value('org_clinic', 'system_resource_panacelin'), 0);
    if v_resource_panacelin < v_med_clinic_panacelin_price then
      perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Не удалось', 'Недостаточно ресурсов');
      return;
    end if;
    v_changes := array_append(v_changes, data.attribute_change2jsonb('system_resource_panacelin', to_jsonb(v_resource_panacelin - v_med_clinic_panacelin_price)));
    perform data.change_object_and_notify(data.get_object_id('org_clinic'), 
                                         to_jsonb(v_changes),
                                         null);
  end if;  

  v_changes := array[]::jsonb[];
  if pp_utils.is_in_group(v_actor_id, 'unofficial_doctor') then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('med_clinic_money', to_jsonb(v_clinic_money - v_med_clinic_money_price)));
  elsif pp_utils.is_in_group(v_actor_id, 'doctor') then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('resource_panacelin', to_jsonb(v_resource_panacelin - v_med_clinic_panacelin_price)));
  end if;

  perform data.change_object_and_notify(data.get_object_id(v_med_computer_code), 
                                        to_jsonb(v_changes));



    if v_disease = 'wound' then
        perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Вы провели хирургическую операцию', 'Спросите у пациента, как он себя чувствует');
    else
      perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Вы дали пациенту лекарство', 'Спросите у него, как он себя чувствует');
    end if;
  end;
$$
language plpgsql;
