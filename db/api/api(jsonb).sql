-- Function: api.api(jsonb)

-- DROP FUNCTION api.api(jsonb);

CREATE OR REPLACE FUNCTION api.api(in_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_client text;
  v_function text;
  v_params jsonb;

  v_current_time timestamp with time zone := now();
  v_login_id integer;
  v_is_admin boolean;
  v_is_active boolean;

  v_schema text;

  v_result api.result;
begin
  perform api_utils.run_deferred_functions();

  v_client := json.get_string(in_params, 'client');
  v_function := json.get_string(in_params, 'function');
  v_params := json.get_object(in_params, 'params');

  select login_id
  into v_login_id
  from data.client_login
  where client = v_client;

  if v_login_id is null then
    v_login_id := data.get_integer_param('default_login');
  end if;

  select is_admin, is_active
  into v_is_admin, v_is_active
  from data.logins
  where id = v_login_id;

  if v_is_admin is null then
    raise exception 'Value of param "default_login" is invalid';
  end if;

  if not v_is_active then
    raise exception 'Inactive login!';
  end if;

  select 'user_api'
  into v_schema
  from information_schema.routines
  where
    routines.specific_schema = 'user_api' and
    routines.routine_name = v_function;

  if v_schema is null then
    select 'admin_api'
    into v_schema
    from information_schema.routines
    where
      routines.specific_schema = 'admin_api' and
      routines.routine_name = v_function;

    if v_schema is not null and not v_is_admin then
      return api_utils.create_forbidden_result('User has no administrator privileges');
    end if;
  end if;

  if v_schema is null then
    return api_utils.create_bad_request_result(format('Unknown function "%s"', v_function));
  end if;

  loop
    begin
      execute format('select * from %s.%s($1, $2, $3)', v_schema, v_function)
      using v_client, v_login_id, v_params
      into v_result;

      return v_result;
    exception when deadlock_detected then
    end;
  end loop;
exception when invalid_parameter_value then
  declare
    v_exception_message text;
    v_exception_call_stack text;
  begin
    get stacked diagnostics
      v_exception_message = message_text,
      v_exception_call_stack = pg_exception_context;

    perform data.log(
      'ERROR',
      format(E'Bad request\nError: %s\nParams:\n%s\nCall stack:\n%s', v_exception_message, in_params, v_exception_call_stack),
      v_client,
      v_login_id);

    return api_utils.create_bad_request_result(v_exception_message);
  end;
when others then
  declare
    v_exception_message text;
    v_exception_call_stack text;
  begin
    get stacked diagnostics
      v_exception_message = message_text,
      v_exception_call_stack = pg_exception_context;

    perform data.log(
      'ERROR',
      format(E'Internal server error\nError: %s\nParams:\n%s\nCall stack:\n%s', v_exception_message, in_params, v_exception_call_stack),
      v_client,
      v_login_id);

    return api_utils.create_internal_server_error_result(v_exception_message);
  end;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE SECURITY DEFINER
  COST 100;
GRANT EXECUTE ON FUNCTION api.api(jsonb) TO http;
