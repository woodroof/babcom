-- drop function pallas_project.act_chat_add_person(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_chat_add_person(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_chat_code text := json.get_string(in_params, 'chat_code');
begin
  assert in_request_id is not null;

  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_chat_code || '_person_list');
end;
$$
language plpgsql;
