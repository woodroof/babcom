-- drop function pallas_project.act_med_diagnostic(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_med_diagnostic(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_person_code text := json.get_string(in_params, 'person_code');
  v_med_health jsonb;
  v_diseases text[];
  v_disease text;
  v_level integer;
  v_message text;
begin
  assert in_request_id is not null;

  v_med_health := coalesce(data.get_attribute_value_for_update(v_person_code || '_med_health', 'med_health'), jsonb '{}');

  select array_agg(x) into v_diseases from jsonb_object_keys(v_med_health) as x
  where x in ('wound', 'radiation', 'asthma', 'rio_miamore', 'addiction', 'sleg_addiction', 'genetic')
    and json.get_integer_opt(json.get_object_opt(v_med_health, x, jsonb '{}'), 'level', 0) <> 0;

  if v_diseases is not null and coalesce(array_length(v_diseases, 1), 0) > 0 then
    v_disease := v_diseases[random.random_integer(1, array_length(v_diseases, 1))];
    v_level := json.get_integer(json.get_object(v_med_health, v_disease), 'level');
    v_message := data.get_string_param('med_diag_' || v_disease || '_' || v_level);
    perform pallas_project.act_med_set_disease_level(
      null, 
      null, 
      format('{"person_code": "%s", "disease": "%s", "level": %s}', v_person_code, v_disease, v_level + 1)::jsonb, 
      null, 
      null);
  end if;
  if coalesce(v_message, '') = '' then
    v_message := 'Состояние не определено.';
  end if;
  perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Сообщение аппарата диагностики', v_message);

end;
$$
language plpgsql;
