-- drop function pallas_project.act_claim_create(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_claim_create(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_claim_list text := json.get_string(in_params, 'claim_list');
  v_claim_list_id integer;
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_actor_code text := data.get_object_code(v_actor_id);

  v_claim_title text := json.get_string(in_user_params, 'title');
  v_claim_text text := json.get_string(in_user_params, 'claim_text');
  v_claim_plaintiff text;
  v_claim_id integer;
  v_claim_code text;
  v_service_status integer := json.get_integer_opt(data.get_attribute_value_for_share(v_actor_id, 'system_person_administrative_services_status'), 0);
begin
  assert in_request_id is not null;

  if v_service_status < 1 then
    perform api_utils.create_show_message_action_notification(
        in_client_id,
        in_request_id,
        'Вы не можете создать иск',
        'Для этого действия у вас должен быть как минимум бронзовый статус в администранивном обслуживании'); 
      return;
  end if;

  if v_claim_list in ('claims_my', 'claims_all', 'claims') then
    v_claim_plaintiff := v_actor_code;
    v_claim_list_id := data.get_object_id('claims_my');
  else
    v_claim_plaintiff := replace(v_claim_list, '_claims', '');
    v_claim_list_id := data.get_object_id(v_claim_list);
  end if;
  -- создаём новый иск
  v_claim_id := data.create_object(
    null,
    jsonb_build_array(
      jsonb_build_object('code', 'title', 'value', v_claim_title),
      jsonb_build_object('code', 'claim_author', 'value', v_actor_code),
      jsonb_build_object('code', 'claim_plaintiff', 'value', v_claim_plaintiff),
      jsonb_build_object('code', 'claim_status', 'value', 'draft'),
      jsonb_build_object('code', 'claim_text', 'value', v_claim_text),
      jsonb_build_object('code', 'claim_time', 'value', pp_utils.format_date(clock_timestamp()))
    ),
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
  if v_claim_list in ('claims_my', 'claims_all', 'claims') then
    perform pp_utils.list_prepend_and_notify(v_claim_list_id, v_claim_code, v_actor_id);
  else
    perform pp_utils.list_prepend_and_notify(v_claim_list_id, v_claim_code, null);
  end if;

  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_claim_code);
 end;
$$
language plpgsql;
