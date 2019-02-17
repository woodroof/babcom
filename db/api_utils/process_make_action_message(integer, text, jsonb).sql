-- drop function api_utils.process_make_action_message(integer, text, jsonb);

create or replace function api_utils.process_make_action_message(in_client_id integer, in_request_id text, in_message jsonb)
returns void
volatile
as
$$
declare
  v_action_code text := json.get_string(in_message, 'action_code');
  v_params jsonb := in_message->'params';
  v_user_params jsonb := json.get_object_opt(in_message, 'user_params', null);
  v_actor_id integer;
  v_function text;
  v_default_params jsonb;
begin
  assert in_message ? 'params';
  assert in_client_id is not null;
  assert in_request_id is not null;

  select actor_id
  into v_actor_id
  from data.clients
  where id = in_client_id
  for share;

  if v_actor_id is null then
    raise exception 'Client % has no active actor', in_client_id;
  end if;

  select function, default_params
  into v_function, v_default_params
  from data.actions
  where code = v_action_code;

  if v_function is null then
    raise exception 'Function with code % not found', v_action_code;
  end if;

  execute format('select %s($1, $2, $3, $4, $5)', v_function)
  using in_client_id, in_request_id, v_params, v_user_params, v_default_params;
end;
$$
language plpgsql;
