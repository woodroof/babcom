-- drop function api_utils.create_show_message_action_notification(integer, text, text, text);

create or replace function api_utils.create_show_message_action_notification(in_client_id integer, in_request_id text, in_title text, in_description text)
returns void
volatile
as
$$
declare
  v_action_data jsonb := jsonb_build_object('message', in_description);
begin
  assert in_description is not null and trim(leading E' \t\n' from in_description) != '';

  if in_title is not null then
    v_action_data := v_action_data || jsonb_build_object('title', in_title);
  end if;

  perform api_utils.create_action_notification(
    in_client_id,
    in_request_id,
    'show_message',
    v_action_data);
end;
$$
language plpgsql;
