-- drop function pallas_project.act_claim_result(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_claim_result(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_claim_code text := json.get_string(in_params, 'claim_code');
  v_claim_result text := json.get_string(in_user_params, 'claim_result');
  v_claim_id integer := data.get_object_id(v_claim_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_actor_code text :=data.get_object_code(v_actor_id);

  v_is_master boolean := pp_utils.is_in_group(v_actor_id, 'master');
  v_is_judge boolean := pp_utils.is_in_group(v_actor_id, 'judge');

  v_claim_status text;
  v_claim_author text := json.get_string(data.get_attribute_value(v_claim_id, 'claim_author'));
  v_claim_plaintiff text := json.get_string(data.get_attribute_value(v_claim_id, 'claim_plaintiff'));
  v_claim_defendant text := json.get_string_opt(data.get_attribute_value_for_share(v_claim_id, 'claim_defendant'), null);
  v_claim_title text := json.get_string_opt(data.get_raw_attribute_value_for_share(v_claim_id, 'title'), '');

  v_claim_author_id integer := data.get_object_id_opt(v_claim_author);
  v_claim_plaintiff_id integer := data.get_object_id_opt(v_claim_plaintiff);
  v_claim_defendant_id integer := data.get_object_id_opt(v_claim_defendant);

  v_claim_plaintiff_type text;
  v_claim_defendant_type text;

  v_claim_to_asj boolean;
  v_organization_name text;

  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');

  v_content text[];
  v_new_content text[];
  v_claims_my_id integer := data.get_object_id('claims_my');
  v_claims_all_id integer := data.get_object_id('claims_all');

  v_changes jsonb[];
  v_message_sent boolean;

  v_person_id integer;
begin
  assert in_request_id is not null;

  v_claim_status := json.get_string_opt(data.get_attribute_value_for_update(v_claim_id, 'claim_status'), '~~~');
  v_claim_plaintiff_type := json.get_string_opt(data.get_attribute_value(v_claim_plaintiff_id, 'type'), null);
  v_claim_defendant_type := json.get_string_opt(data.get_attribute_value(v_claim_defendant_id, 'type'), null);
  v_claim_to_asj := json.get_boolean_opt(data.get_attribute_value_for_update(v_claim_id, 'system_claim_to_asj'), false);

  if v_claim_status = 'processing' and (v_is_master or (v_is_judge and not v_claim_to_asj) or (v_actor_code = 'asj' and v_claim_to_asj)) then
    -- Отправляем мастерам в чат уведомление 
    perform pallas_project.send_to_master_chat('По иску "' || v_claim_title || '" принято решение' , v_claim_code);

    -- Уведомляем автора
    perform pp_utils.add_notification(v_claim_author_id, 'По вашему иску "' || v_claim_title || '" принято решение. Зайдите в иск, чтобы с ним ознакомиться', v_claim_id, true);
    -- Рассылаем уведомления ответчику
    if v_claim_defendant_type = 'person' then
      perform pp_utils.add_notification(v_claim_defendant_id, 'По иску "' || v_claim_title || '", для которого вы являетесь ответчиком, принято решение. Зайдите в иск, чтобы с ним ознакомиться', v_claim_id, true);
      perform pp_utils.list_prepend_and_notify(v_claims_my_id, v_claim_code, v_claim_defendant_id, v_actor_id);
    elsif v_claim_defendant_type = 'organization' then
      perform pp_utils.list_prepend_and_notify(data.get_object_id(v_claim_defendant || '_claims'), v_claim_code, null, v_actor_id);
      if data.is_object_exists(v_claim_defendant || '_head') then
        v_organization_name := json.get_string(data.get_attribute_value(v_claim_defendant_id, 'title'));
        for v_person_id in (select * from unnest(pallas_project.get_group_members(v_claim_defendant || '_head'))) loop
          perform pp_utils.add_notification(v_person_id, 'По иску "' || v_claim_title || '", для которого ваша организация "'|| v_organization_name ||'" является ответчиком, принято решение. Зайдите в иск, чтобы с ним ознакомиться', v_claim_id, true);
        end loop;
      end if;
    end if;

  else
     perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Ошибка',
      'Некорректное изменение статуса иска'); 
    return;
  end if;

  v_changes := array_append(v_changes, data.attribute_change2jsonb('claim_status', jsonb '"done"'));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('claim_result_time', to_jsonb(pp_utils.format_date(clock_timestamp()))));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('claim_result_text', to_jsonb(E'\n' || v_claim_result)));
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               v_claim_id, 
                                               to_jsonb(v_changes));
  if not v_message_sent then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
