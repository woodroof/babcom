-- drop function pallas_project.create_claim(jsonb, text);

create or replace function pallas_project.create_claim(in_attributes jsonb, in_claim_list text)
returns void
volatile
as
$$
declare
  v_claim_list_id integer := data.get_object_id(in_claim_list);
  v_actor_id integer := data.get_object_id(json.get_string(in_attributes, 'claim_author'));
  v_claim_defendant text := json.get_string(in_attributes, 'claim_defendant');
  v_claim_defendant_id integer := data.get_object_id(v_claim_defendant);

  v_claim_title text := json.get_string(in_attributes, 'title');
  v_claim_id integer;
  v_claim_code text;

  v_claims_all_id integer := data.get_object_id('claims_all');
  v_claims_my_id integer := data.get_object_id('claims_my');
  v_claim_defendant_type text := json.get_string_opt(data.get_attribute_value(v_claim_defendant_id, 'type'), null);
  v_organization_name text;
  v_person_id integer;
begin
  -- создаём новый иск
  v_claim_id := data.create_object(
    null,
    in_attributes,
    'claim');
  v_claim_code := data.get_object_code(v_claim_id);

  perform pallas_project.create_chat(v_claim_code || '_chat',
                   jsonb_build_object(
                   'content', jsonb '[]',
                   'title', 'Обсуждение иска ' || v_claim_title,
                   'system_chat_is_renamed', true,
                   'system_chat_can_invite', false,
                   'system_chat_can_leave', false,
                   'system_chat_can_rename', false,
                   'system_chat_cant_see_members', true,
                   'system_chat_length', 0
                 ));

  -- Кладём иск в начало списка
  if in_claim_list in ('claims_my') then
   perform pp_utils.list_prepend_and_notify(v_claims_my_id, v_claim_code, v_actor_id);
  else
   perform pp_utils.list_prepend_and_notify(v_claim_list_id, v_claim_code, null);
  end if;
  perform pp_utils.list_prepend_and_notify(v_claims_all_id, v_claim_code, null);

  --Уведомления 
  perform pallas_project.send_to_master_chat('Создан новый иск. Направлен судье.', v_claim_code);
  perform pp_utils.add_notification(v_actor_id, 'Ваш иск "' || v_claim_title || '" направлен на рассмотрение судье.', v_claim_id, true);

  if v_claim_defendant_type = 'person' then
    perform pp_utils.add_notification(v_claim_defendant_id, 'Вы являетесь ответчиком по иску "' || v_claim_title || '". Иск направлен судье.', v_claim_id, true);
    perform pp_utils.list_prepend_and_notify(v_claims_my_id, v_claim_code, v_claim_defendant_id, v_actor_id);
  elsif v_claim_defendant_type = 'organization' then
    perform pp_utils.list_prepend_and_notify(data.get_object_id(v_claim_defendant || '_claims'), v_claim_code, null, v_actor_id);
    if data.is_object_exists(v_claim_defendant || '_head') then
      v_organization_name := json.get_string(data.get_attribute_value(v_claim_defendant_id, 'title'));
      for v_person_id in (select * from unnest(pallas_project.get_group_members(v_claim_defendant || '_head'))) loop
        perform pp_utils.add_notification(v_person_id, 'Ваша организация "'|| v_organization_name ||'" является ответчиком по иску "' || v_claim_title || '". Иск направлен судье.', v_claim_id, true);
      end loop;
    end if;
  end if;
  for v_person_id in (select * from unnest(pallas_project.get_group_members('judge'))) loop
    perform pp_utils.add_notification(v_person_id, 'Вам на рассмотрение передан иск', v_claim_id, true);
  end loop;

end;
$$
language plpgsql;
