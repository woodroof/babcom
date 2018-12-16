-- drop function api_utils.process_get_actors_message(integer, integer, text, jsonb);

create or replace function api_utils.process_get_actors_message(in_client_id integer, in_actor_id integer, in_request_id text, in_message_data jsonb)
returns void
volatile
as
$$
begin
  assert in_request_id is not null;
  assert v_objects is not null;

  -- todo
  perform api_utils.create_notification(in_client_id, in_request_id, 'actors', jsonb_build_object('actors', null));
end;
$$
language 'plpgsql';
