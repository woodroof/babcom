-- drop function api.api(text, jsonb);

create or replace function api.api(in_client_code text, in_message jsonb)
returns void
volatile
security definer
as
$$
declare
  v_request_id text;
  v_type text;
  v_client_id integer;
  v_login_id integer;
  v_check_result boolean;
  v_deadlock_count integer := 0;
  v_start_time timestamp with time zone := clock_timestamp();
  v_ms integer;
begin
  begin
    v_request_id := json.get_string(in_message, 'request_id');

    assert in_client_code is not null;

    select id
    into v_client_id
    from data.clients
    where
      code = in_client_code and
      is_connected = true;

    if v_client_id is null then
      raise exception 'Client with code "%" is not connected', in_client_code;
    end if;

    v_type := json.get_string(in_message, 'type');

    loop
      begin
        if v_type = 'get_actors' then
          perform api_utils.process_get_actors_message(v_client_id, v_request_id);
        elsif v_type = 'set_actor' then
          perform api_utils.process_set_actor_message(v_client_id, v_request_id, json.get_object(in_message, 'data'));
        elsif v_type = 'subscribe' then
          perform api_utils.process_subscribe_message(v_client_id, v_request_id, json.get_object(in_message, 'data'));
        elsif v_type = 'get_more' then
          perform api_utils.process_get_more_message(v_client_id, v_request_id, json.get_object(in_message, 'data'));
        elsif v_type = 'unsubscribe' then
          perform api_utils.process_unsubscribe_message(v_client_id, v_request_id, json.get_object(in_message, 'data'));
        elsif v_type = 'make_action' then
          perform api_utils.process_make_action_message(v_client_id, v_request_id, json.get_object(in_message, 'data'));
        elseif v_type = 'touch' then
          perform api_utils.process_touch_message(v_client_id, v_request_id, json.get_object(in_message, 'data'));
        elseif v_type = 'open_list_object' then
          perform api_utils.process_open_list_object_message(v_client_id, v_request_id, json.get_object(in_message, 'data'));
        else
          raise exception 'Unsupported message type "%"', v_type;
        end if;

        exit;
      exception when deadlock_detected then
        v_deadlock_count := v_deadlock_count + 1;
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
        format(E'Error: %s\nMessage:\n%s\nClient: %s\nCall stack:\n%s', v_exception_message, in_message, in_client_code, v_exception_call_stack));

      -- Ошибка могла возникнуть до заполнения v_client_id
      if v_client_id is null then
        select id
        into v_client_id
        from data.clients
        where
          code = in_client_code and
          is_connected = true;
      end if;

      if v_client_id is not null then
        perform api_utils.create_notification(v_client_id, v_request_id, 'error', jsonb '{}');
      end if;
    end;
  end;

  if v_deadlock_count > 0 then
    perform data.metric_add('deadlock_count', v_deadlock_count);
  end if;

  v_ms := (extract(epoch from clock_timestamp() - v_start_time) * 1000)::integer;
  perform data.metric_set_max('max_api_time_ms', v_ms);
  if v_ms >= 500 then
    perform data.log('warning', format(E'Slow api request detected: %s ms\nClient: %s\nMessage:\n%s', v_ms, in_client_code, in_message));
  end if;
end;
$$
language plpgsql;
