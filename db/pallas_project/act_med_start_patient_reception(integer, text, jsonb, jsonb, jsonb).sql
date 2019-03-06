-- drop function pallas_project.act_med_start_patient_reception(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_med_start_patient_reception(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_client_code text;
  v_patient_login text := json.get_string(in_user_params, 'patient_login');
  v_med_comp_client_ids text[] := json.get_string_array(data.get_param('med_comp_client_ids'));
  v_object_id integer;
  v_object_code text;
  v_person_id integer;
  v_med_health jsonb;
  v_clinic_money bigint;
  v_health_care_status integer;
  v_orig_health_care_status integer;
  v_attributes jsonb;
  v_med_skill integer := json.get_integer_opt(data.get_attribute_value(v_actor_id, 'system_person_med_skill'), null);
  v_is_stimulant boolean := json.get_boolean_opt(data.get_attribute_value(v_actor_id, 'system_person_is_stimulant_used'), null);
  v_resource_panacelin integer;
begin
  assert in_request_id is not null;
  select code into v_client_code from data.clients c where id = in_client_id;
  if array_position(v_med_comp_client_ids, coalesce(v_client_code, '~')) is null then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Зайдите со стационарного медицинского компьютера');
    return;
  end if;
  select min(la.actor_id) into v_person_id from data.logins l
    inner join data.login_actors la on l.id = la.login_id
  where l.code = v_patient_login;

  v_person_id := json.get_integer_opt(data.get_attribute_value(v_person_id, 'system_person_original_id'), v_person_id);

  v_med_health := coalesce(data.get_attribute_value(data.get_object_code(v_person_id) || '_med_health', 'med_health'), jsonb '{}');

 select coalesce(max(json.get_integer_opt(data.get_attribute_value_for_share(x, 'system_person_health_care_status'), 0)), 0) into v_health_care_status 
  from unnest(json.get_integer_array_opt(data.get_attribute_value(v_person_id, 'system_person_doubles_id_list'), array[]::integer[])) as x;
  v_orig_health_care_status := json.get_integer_opt(data.get_attribute_value_for_share(v_person_id, 'system_person_health_care_status'), 0);
  if v_orig_health_care_status > v_health_care_status then
    v_health_care_status := v_orig_health_care_status;
  end if;

  v_attributes :=  jsonb_build_object(
    'med_person_code', data.get_object_code(v_person_id),
    'med_health', v_med_health,
    'med_health_care_status', v_health_care_status
  );

  if v_med_skill is not null then
    v_attributes :=  v_attributes || jsonb_build_object('med_skill', v_med_skill);
  end if;
  if v_is_stimulant is not null then
    v_attributes :=  v_attributes || jsonb_build_object('is_stimulant_used', v_is_stimulant);
  end if;

  if pp_utils.is_in_group(v_actor_id, 'unofficial_doctor') then
    v_clinic_money := json.get_bigint_opt(data.get_attribute_value('org_clean_asteroid', 'system_money'), 0);
    v_attributes := v_attributes || jsonb_build_object('med_clinic_money', v_clinic_money);
  elsif pp_utils.is_in_group(v_actor_id, 'doctor') then
    v_resource_panacelin := json.get_bigint_opt(data.get_attribute_value('org_clinic', 'system_resource_panacelin'), 0);
    v_attributes := v_attributes || jsonb_build_object('resource_panacelin', v_resource_panacelin);
  end if;

  v_object_id := data.create_object(
    null,
    v_attributes,
    'med_computer');

  v_object_code := data.get_object_code(v_object_id);


  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_object_code);
end;
$$
language plpgsql;
