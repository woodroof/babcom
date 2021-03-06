-- drop function pallas_project.act_document_share(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_share(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_share_list_code text := json.get_string(in_params, 'share_list_code');
  v_share_list_id integer := data.get_object_id(v_share_list_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_document_id integer := json.get_integer(data.get_attribute_value(v_share_list_id, 'system_document_temp_list_document_id'));

  v_system_document_temp_share_list integer[] := json.get_integer_array_opt(data.get_attribute_value(v_share_list_id, 'system_document_temp_share_list'), array[]::integer[]);

  v_person_id integer;
  v_message text := 'Пользователь "' || json.get_string(data.get_attribute_value(v_actor_id, 'title')) || '" поделился с вами документом';
  v_title_attr_id integer := data.get_attribute_id('title');
  v_persons text;
  v_person_message text := 'Вы поделились документом со следующими пользователями: ';
begin
  assert in_request_id is not null;

  select string_agg(json.get_string(data.get_attribute_value(a.value, v_title_attr_id)), ', ')
  into v_persons
  from unnest(v_system_document_temp_share_list) a(value);

  v_person_message := v_person_message || v_persons;

  for v_person_id in (select * from unnest(v_system_document_temp_share_list)) loop
    perform pp_utils.add_notification(v_person_id, v_message, v_document_id, true);
  end loop;
  perform pp_utils.add_notification(v_actor_id, v_person_message, v_document_id, true);

  perform api_utils.create_go_back_action_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;
