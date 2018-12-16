-- drop function api.api(text, jsonb);

create or replace function api.api(in_client_code text, in_message jsonb)
returns void
volatile
as
$$
declare
  v_request_id text := json.get_string(in_message, 'request_id');
  v_type text := json.get_string(in_message, 'type');
  v_client_id integer;
  v_actor_id integer;
  v_check_result boolean;
  v_function text;
begin
  assert in_client_code is not null;

  select id, actor_id
  into v_client_id, v_actor_id
  from data.clients
  where
    code = in_client_code and
    is_connected = true;

  if v_client_id is null then
    raise exception 'Client with code "%s" is not connected', in_client_code;
  end if;

  v_function =
    case
      when v_type = 'get_actors' then 'process_get_actors_message'
      else null
     end;
  if v_function is null then
    raise exception 'Unsupported message type "%s"', v_type;
  end if;

  loop
    begin
      execute format('select * from api_utils.%s($1, $2, $3, $4)', v_function)
      using v_client_id, v_actor_id, v_request_id, in_message->'data';

      return;
    exception when deadlock_detected then
    end;
  end loop;
exception when others or assert_failure then
  declare
    v_exception_message text;
    v_exception_call_stack text;
  begin
    get stacked diagnostics
      v_exception_message = message_text,
      v_exception_call_stack = pg_exception_context;

    perform data.log(
      'error',
      format(E'Error: %s\nMessage:\n%s\nCall stack:\n%s', v_exception_message, in_message, v_exception_call_stack),
      v_actor_id);
  end;
end;
$$
language 'plpgsql';
