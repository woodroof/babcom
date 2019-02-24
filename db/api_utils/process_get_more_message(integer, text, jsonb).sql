-- drop function api_utils.process_get_more_message(integer, text, jsonb);

create or replace function api_utils.process_get_more_message(in_client_id integer, in_request_id text, in_message jsonb)
returns void
volatile
as
$$
declare
  v_object_id integer := data.get_object_id(json.get_string(in_message, 'object_id'));
  v_actor_id integer;
  v_list jsonb;
begin
  assert in_client_id is not null;

  select actor_id
  into v_actor_id
  from data.clients
  where id = in_client_id
  for share;

  if v_actor_id is null then
    raise exception 'Client % has no active actor', in_client_id;
  end if;

  v_list := data.get_next_list(in_client_id, v_object_id);
  assert v_list is not null;

  perform api_utils.create_notification(in_client_id, in_request_id, 'object_list', jsonb_build_object('list', v_list));
end;
$$
language plpgsql;
