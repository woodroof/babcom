-- drop function pallas_project.act_open_object(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_open_object(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
v_object_code text := json.get_string(in_params, 'object_code');
begin
  assert in_request_id is not null;

  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'action',
    format('{"action": "open_object", "action_data": {"object_id": "%s"}}', v_object_code)::jsonb);
end;
$$
language 'plpgsql';
