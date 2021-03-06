-- drop function pallas_project.act_med_open_medicine(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_med_open_medicine(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_med_comp_client_ids text[] := json.get_string_array(data.get_param('med_comp_client_ids'));
  v_object_code text;
  v_client_code text;
begin
  assert in_request_id is not null;
  select code into v_client_code from data.clients c where id = in_client_id;
  if array_position(v_med_comp_client_ids, coalesce(v_client_code, '~')) is not null then
    v_object_code := 'medicine';
  else
    v_object_code := 'wrong_medicine';
  end if;
  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_object_code);
end;
$$
language plpgsql;
