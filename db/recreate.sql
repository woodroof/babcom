-- Cleaning database

create schema if not exists database_cleanup;

create or replace function database_cleanup.clean()
returns void as
$$
declare
  v_schema_name text;
begin
  for v_schema_name in
  (
    select nspname as name
    from pg_namespace
    where nspname not like 'pg\_%' and nspname not in ('information_schema', 'database_cleanup')
  )
  loop
    execute format('drop schema %s cascade', v_schema_name);
  end loop;
end;
$$
language plpgsql;

select database_cleanup.clean();

drop schema database_cleanup cascade;

-- Creating extensions

create schema intarray;
create extension intarray schema intarray;

create schema pgcrypto;
create extension pgcrypto schema pgcrypto;

-- Creating schemas

-- drop schema api;

create schema api;
comment on schema api is 'Функции, вызываемые web-сервером';

-- drop schema api_utils;

create schema api_utils;

-- drop schema array_utils;

create schema array_utils;

-- drop schema data;

create schema data;

-- drop schema data_internal;

create schema data_internal;

-- drop schema error;

create schema error;

-- drop schema job_test_project;

create schema job_test_project;

-- drop schema json;

create schema json;

-- drop schema json_test;

create schema json_test;

-- drop schema pallas_project;

create schema pallas_project;

-- drop schema pp_utils;

create schema pp_utils;

-- drop schema random;

create schema random;

-- drop schema random_test;

create schema random_test;

-- drop schema test;

create schema test;

-- drop schema test_project;

create schema test_project;

-- Creating enums

-- drop type api_utils.action_type;

create type api_utils.action_type as enum(
  'go_back',
  'open_object',
  'show_message');

-- drop type api_utils.output_message_type;

create type api_utils.output_message_type as enum(
  'action',
  'actors',
  'diff',
  'error',
  'object',
  'object_list',
  'ok');

-- drop type data.attribute_type;

create type data.attribute_type as enum(
  'system',
  'hidden',
  'normal');

-- drop type data.card_type;

create type data.card_type as enum(
  'full',
  'mini');

-- drop type data.metric_type;

create type data.metric_type as enum(
  'deadlock_count',
  'error_count',
  'max_api_time_ms',
  'max_job_time_ms');

-- drop type data.notification_type;

create type data.notification_type as enum(
  'client_message',
  'metric',
  'job');

-- drop type data.object_type;

create type data.object_type as enum(
  'class',
  'instance');

-- drop type data.severity;

create type data.severity as enum(
  'error',
  'warning',
  'info');

-- Creating functions

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

  perform data.metric_set_max('max_api_time_ms', extract(milliseconds from clock_timestamp() - v_start_time)::integer);
end;
$$
language plpgsql;

-- drop function api.connect_client(text);

create or replace function api.connect_client(in_client_code text)
returns void
volatile
security definer
as
$$
declare
  v_client_id integer;
  v_is_connected boolean;
begin
  assert in_client_code is not null;

  select id, is_connected
  into v_client_id, v_is_connected
  from data.clients
  where code = in_client_code
  for update;

  if v_client_id is null then
    insert into data.clients(code, is_connected)
    values(in_client_code, true);
  else
    if v_is_connected = true then
      raise exception 'Client with code "%" already connected', in_client_code;
    end if;

    update data.clients
    set is_connected = true
    where id = v_client_id;

    perform data.log('info', format('Connected client with code "%s"', in_client_code));
  end if;
end;
$$
language plpgsql;

-- drop function api.disconnect_all_clients();

create or replace function api.disconnect_all_clients()
returns void
volatile
security definer
as
$$
begin
  delete from data.notifications;
  delete from data.client_subscription_objects;
  delete from data.client_subscriptions;

  update data.clients
  set
    is_connected = false,
    actor_id = null;

  perform data.log('info', 'All clients were disconnected');
end;
$$
language plpgsql;

-- drop function api.disconnect_client(text);

create or replace function api.disconnect_client(in_client_code text)
returns void
volatile
security definer
as
$$
declare
  v_client_id integer;
begin
  assert in_client_code is not null;

  select id
  into v_client_id
  from data.clients
  where
    code = in_client_code and
    is_connected = true
  for update;

  if v_client_id is null then
    raise exception 'Client with code "%" is not connected', in_client_code;
  end if;

  update data.clients
  set
    is_connected = false,
    actor_id = null
  where id = v_client_id;

  delete from data.notifications
  where client_id = v_client_id;

  delete from data.client_subscription_objects
  where client_subscription_id in (
    select id
    from data.client_subscriptions
    where client_id = v_client_id);

  delete from data.client_subscriptions
  where client_id = v_client_id;

  perform data.log('info', format('Disconnected client with code "%s"', in_client_code));
end;
$$
language plpgsql;

-- drop function api.get_notification(text);

create or replace function api.get_notification(in_notification_code text)
returns jsonb
volatile
security definer
as
$$
declare
  v_type data.notification_type;
  v_message jsonb;
begin
  assert in_notification_code is not null;

  delete from data.notifications
  where code = in_notification_code
  returning type, message
  into v_type, v_message;

  -- Уведомление могло удалиться из-за отключения клиента
  if v_type is null then
    return null;
  end if;

  return
    jsonb_build_object(
      'type',
      v_type::text,
      'message',
      v_message);
end;
$$
language plpgsql;

-- drop function api.run_jobs();

create or replace function api.run_jobs()
returns void
volatile
security definer
as
$$
declare
  v_function text;
  v_params jsonb;
  v_desired_time timestamp with time zone;
  v_deadlock_count integer := 0;
  v_start_time timestamp with time zone;
begin
  loop
    delete from data.jobs
    where id in (
      select id
      from data.jobs
      where desired_time <= clock_timestamp()
      order by desired_time
      limit 1)
    returning function, params into v_function, v_params;

    if v_function is null then
      exit;
    end if;

    v_start_time := clock_timestamp();

    loop
      begin
        execute format('select %s($1)', v_function)
        using v_params;

        exit;
      exception when deadlock_detected then
        v_deadlock_count := v_deadlock_count + 1;
      when others or assert_failure then
        declare
          v_exception_message text;
          v_exception_call_stack text;
        begin
          get stacked diagnostics
            v_exception_message = message_text,
            v_exception_call_stack = pg_exception_context;

          perform data.log(
            'error',
            format(E'Error: %s\nJob function: %s\nJob params: %s\nCall stack:\n%s', v_exception_message, v_function, v_params, v_exception_call_stack));

          -- При ошибке пропускаем job'у, всё равно увидем её и её параметры в логе и сможем повторить
          exit;
        end;
      end;
    end loop;

    perform data.metric_set_max('max_job_time_ms', extract(milliseconds from clock_timestamp() - v_start_time)::integer);
  end loop;

  select min(desired_time)
  into v_desired_time
  from data.jobs;

  if v_desired_time is not null then
    perform api_utils.create_job_notification(v_desired_time);
  end if;

  if v_deadlock_count > 0 then
    perform data.metric_add('deadlock_count', v_deadlock_count);
  end if;
end;
$$
language plpgsql;

-- drop function api_utils.create_action_notification(integer, text, api_utils.action_type, jsonb);

create or replace function api_utils.create_action_notification(in_client_id integer, in_request_id text, in_action_type api_utils.action_type, in_action_data jsonb)
returns void
volatile
as
$$
begin
  perform json.get_object(in_action_data);

  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'action',
    jsonb_build_object('action', in_action_type, 'action_data', in_action_data));
end;
$$
language plpgsql;

-- drop function api_utils.create_go_back_action_notification(integer, text);

create or replace function api_utils.create_go_back_action_notification(in_client_id integer, in_request_id text)
returns void
volatile
as
$$
begin
  perform api_utils.create_action_notification(
    in_client_id,
    in_request_id,
    'go_back',
    jsonb '{}');
end;
$$
language plpgsql;

-- drop function api_utils.create_job_notification(timestamp with time zone);

create or replace function api_utils.create_job_notification(in_desired_time timestamp with time zone)
returns void
volatile
as
$$
declare
  v_timeout_sec double precision := greatest(extract(seconds from in_desired_time - clock_timestamp()), 0.);
  v_notification_code text;
begin
  assert in_desired_time is not null;

  insert into data.notifications(type, message)
  values('job', to_jsonb(v_timeout_sec))
  returning code into v_notification_code;

  perform pg_notify('api_channel', jsonb_build_object('notification_code', v_notification_code)::text);
end;
$$
language plpgsql;

-- drop function api_utils.create_metric_notification(data.metric_type, integer);

create or replace function api_utils.create_metric_notification(in_type data.metric_type, in_value integer)
returns void
volatile
as
$$
declare
  v_notification_code text;
begin
  assert in_type is not null;
  assert in_value is not null;

  insert into data.notifications(type, message)
  values('metric', jsonb_build_object('type', in_type::text, 'value', in_value))
  returning code into v_notification_code;

  perform pg_notify('api_channel', jsonb_build_object('notification_code', v_notification_code)::text);
end;
$$
language plpgsql;

-- drop function api_utils.create_notification(integer, text, api_utils.output_message_type, jsonb);

create or replace function api_utils.create_notification(in_client_id integer, in_request_id text, in_type api_utils.output_message_type, in_data jsonb)
returns void
volatile
as
$$
declare
  v_message jsonb :=
    jsonb_build_object(
      'type', in_type::text,
      'data', json.get_object(in_data)) ||
    (case when in_request_id is not null then jsonb_build_object('request_id', in_request_id) else jsonb '{}' end);
  v_notification_code text;
  v_client_code text;
begin
  assert in_client_id is not null;
  assert in_type is not null;

  insert into data.notifications(type, message, client_id)
  values('client_message', v_message, in_client_id)
  returning code into v_notification_code;

  select code
  into v_client_code
  from data.clients
  where id = in_client_id;

  perform pg_notify('api_channel', jsonb_build_object('notification_code', v_notification_code, 'client_code', v_client_code)::text);
end;
$$
language plpgsql;

-- drop function api_utils.create_ok_notification(integer, text);

create or replace function api_utils.create_ok_notification(in_client_id integer, in_request_id text)
returns void
volatile
as
$$
begin
  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'ok',
    jsonb '{}');
end;
$$
language plpgsql;

-- drop function api_utils.create_open_object_action_notification(integer, text, text);

create or replace function api_utils.create_open_object_action_notification(in_client_id integer, in_request_id text, in_object_code text)
returns void
volatile
as
$$
begin
  perform data.get_object_id(in_object_code);

  perform api_utils.create_action_notification(
    in_client_id,
    in_request_id,
    'open_object',
    jsonb_build_object('object_id', in_object_code));
end;
$$
language plpgsql;

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

-- drop function api_utils.process_get_actors_message(integer, text);

create or replace function api_utils.process_get_actors_message(in_client_id integer, in_request_id text)
returns void
volatile
as
$$
declare
  v_default_template jsonb;
  v_login_id integer;
  v_actor_function record;
  v_actor record;
  v_template jsonb;
  v_title text;
  v_title_attribute_id integer;
  v_subtitle text;
  v_subtitle_attribute_id integer;
  v_actors jsonb := '[]';
begin
  assert in_request_id is not null;

  select login_id
  into v_login_id
  from data.clients
  where id = in_client_id
  for share;

  if v_login_id is null then
    v_login_id := data.get_integer_param('default_login_id');
    assert v_login_id is not null;

    update data.clients
    set login_id = v_login_id
    where id = in_client_id;
  end if;

  perform
  from data.logins
  where id = v_login_id
  for share;

  for v_actor_function in
    select actor_id, json.get_string_opt(data.get_attribute_value(actor_id, 'actor_function'), null) as actor_function
    from data.login_actors
    where login_id = v_login_id
  loop
    if v_actor_function is not null then
      execute format('select %s($1)', v_actor_function.actor_function)
      using v_actor_function.actor_id;
    end if;
  end loop;

  for v_actor in
    select
      o.id id,
      o.code as code,
      json.get_object_opt(data.get_attribute_value(la.actor_id, 'template'), null) as template
    from data.login_actors la
    join data.objects o
      on o.id = la.actor_id
    where la.login_id = v_login_id
  loop
    v_template := v_actor.template;

    if v_template is null then
      if v_default_template is null then
        v_default_template := data.get_object_param('template');
      end if;
      v_template := v_default_template;
    end if;

    assert v_template is not null;

    if v_template ? 'title' then
      v_title_attribute_id := data.get_attribute_id(json.get_string(v_template, 'title'));

      if data.can_attribute_be_overridden(v_title_attribute_id) then
        v_title := json.get_string_opt(data.get_attribute_value(v_actor.id, v_title_attribute_id, v_actor.id), null);
      else
        v_title := json.get_string_opt(data.get_attribute_value(v_actor.id, v_title_attribute_id), null);
      end if;
    end if;

    if v_template ? 'subtitle' then
      v_subtitle_attribute_id := data.get_attribute_id(json.get_string(v_template, 'subtitle'));

      if data.can_attribute_be_overridden(v_subtitle_attribute_id) then
        v_subtitle := json.get_string_opt(data.get_attribute_value(v_actor.id, v_subtitle_attribute_id, v_actor.id), null);
      else
        v_subtitle := json.get_string_opt(data.get_attribute_value(v_actor.id, v_subtitle_attribute_id), null);
      end if;
    end if;

    v_actors :=
      v_actors ||
      (
        jsonb_build_object('id', v_actor.code) ||
        case when v_title is not null then jsonb_build_object('title', v_title) else jsonb '{}' end ||
        case when v_subtitle is not null then jsonb_build_object('subtitle', v_subtitle) else jsonb '{}' end
      );
  end loop;

  assert v_actors is not null;

  -- Сортируем по имени
  select jsonb_agg(a.value)
  into v_actors
  from (
    select value
    from jsonb_array_elements(v_actors)
    order by value->'title', value->'subtitle') a;

  perform api_utils.create_notification(in_client_id, in_request_id, 'actors', jsonb_build_object('actors', v_actors));
end;
$$
language plpgsql;

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

-- drop function api_utils.process_open_list_object_message(integer, text, jsonb);

create or replace function api_utils.process_open_list_object_message(in_client_id integer, in_request_id text, in_message jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_message, 'object_id');
  v_list_object_code text := json.get_string(in_message, 'list_object_id');
  v_object_id integer := data.get_object_id(v_object_code);
  v_list_object_id integer := data.get_object_id(v_list_object_code);
  v_content text[];
  v_is_visible boolean;
  v_actor_id integer;
  v_list_element_function text;
begin
  assert in_client_id is not null;
  assert data.is_instance(v_object_id);
  assert data.is_instance(v_list_object_id);

  select actor_id
  into v_actor_id
  from data.clients
  where id = in_client_id
  for share;

  if v_actor_id is null then
    raise exception 'Client % has no active actor', in_client_id;
  end if;

  v_content := json.get_string_array(data.get_attribute_value(v_object_id, 'content', v_actor_id));

  if array_position(v_content, v_list_object_code) is null then
    raise exception 'Object % has no list object %', v_object_code, v_list_object_code;
  end if;

  v_is_visible := json.get_boolean(data.get_attribute_value(v_list_object_id, 'is_visible', v_actor_id));

  if not v_is_visible then
    raise exception 'List object % is not visible', v_list_object_code;
  end if;

  -- Вызываем функцию открытия элемента списка, если есть
  v_list_element_function := json.get_string_opt(data.get_attribute_value(v_object_id, 'list_element_function'), null);

  if v_list_element_function is not null then
    execute format('select %s($1, $2, $3, $4)', v_list_element_function)
    using in_client_id, in_request_id, v_object_id, v_list_object_id;
  else
    perform api_utils.create_open_object_action_notification(
      in_client_id,
      in_request_id,
      v_list_object_code);
  end if;
end;
$$
language plpgsql;

-- drop function api_utils.process_set_actor_message(integer, text, jsonb);

create or replace function api_utils.process_set_actor_message(in_client_id integer, in_request_id text, in_message jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_object_id(json.get_string(in_message, 'actor_id'));
  v_login_id integer;
  v_actor_exists boolean;
begin
  assert in_client_id is not null;

  select login_id
  into v_login_id
  from data.clients
  where id = in_client_id
  for update;

  if v_login_id is null then
    v_login_id := data.get_integer_param('default_login_id');
    assert v_login_id is not null;

    update data.clients
    set login_id = v_login_id
    where id = in_client_id;
  end if;

  perform
  from data.logins
  where id = v_login_id
  for share;

  select true
  into v_actor_exists
  from data.login_actors
  where
    login_id = v_login_id and
    actor_id = v_actor_id;

  if v_actor_exists is null then
    raise exception 'Actor % is not available for client %', v_actor_id, in_client_id;
  end if;

  update data.clients
  set actor_id = v_actor_id
  where id = in_client_id;

  delete from data.client_subscription_objects
  where client_subscription_id in (
    select id
    from data.client_subscriptions
    where client_id = in_client_id);

  delete from data.client_subscriptions
  where client_id = in_client_id;

  perform api_utils.create_ok_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;

-- drop function api_utils.process_subscribe_message(integer, text, jsonb);

create or replace function api_utils.process_subscribe_message(in_client_id integer, in_request_id text, in_message jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_message, 'object_id');
  v_actor_id integer;
  v_object_id integer;
  v_full_card_function text;
  v_redirect_object_id integer;
  v_object_exists boolean;
  v_is_visible boolean;
  v_subscription_exists boolean;
  v_object jsonb;
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

  select id
  into v_object_id
  from data.objects
  where
    code = v_object_code and
    type = 'instance';

  if v_object_id is null then
    perform data.log('warning', format('Attempt to subscribe for non-existing object'' changes with code %s. Redirecting to 404.', v_object_code));
    perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, data.get_object_code(data.get_integer_param('not_found_object_id')));
    return;
  end if;

  -- Вызываем функцию на получение полной карточки объекта, если есть
  v_full_card_function := json.get_string_opt(data.get_attribute_value(v_object_id, 'full_card_function'), null);

  if v_full_card_function is not null then
    execute format('select %s($1, $2)', v_full_card_function)
    using v_object_id, v_actor_id;
  end if;

  -- Смотрим на наличие redirect'а
  v_redirect_object_id := json.get_integer_opt(data.get_attribute_value(v_object_id, 'redirect', v_actor_id), null);
  if v_redirect_object_id is not null then
    perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, data.get_object_code(v_redirect_object_id));
    return;
  end if;

  -- Проверяем видимость
  v_is_visible := json.get_boolean_opt(data.get_attribute_value(v_object_id, 'is_visible', v_actor_id), false);
  if not v_is_visible then
    perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, data.get_object_code(data.get_integer_param('not_found_object_id')));
    return;
  end if;

  select true
  into v_subscription_exists
  from data.client_subscriptions
  where
    object_id = v_object_id and
    client_id = in_client_id;

  if v_subscription_exists then
    raise exception 'Can''t create second subscription to object %', v_object_id;
  end if;

  v_object := data.get_object(v_object_id, v_actor_id, 'full', v_object_id);

  insert into data.client_subscriptions(client_id, object_id)
  values(in_client_id, v_object_id);

  -- Получаем список, если есть
  v_list := data.get_next_list(in_client_id, v_object_id);
  if v_list is not null then
    perform api_utils.create_notification(in_client_id, in_request_id, 'object', jsonb_build_object('object', v_object, 'list', v_list));
  else
    perform api_utils.create_notification(in_client_id, in_request_id, 'object', jsonb_build_object('object', v_object));
  end if;
end;
$$
language plpgsql;

-- drop function api_utils.process_touch_message(integer, text, jsonb);

create or replace function api_utils.process_touch_message(in_client_id integer, in_request text, in_message jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_message, 'object_id');
  v_object_id integer := data.get_object_id(v_object_code);
  v_actor_id integer;
  v_touch_function text;
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

  -- Вызываем функцию смахивания уведомления, если есть
  v_touch_function := json.get_string_opt(data.get_attribute_value(v_object_id, 'touch_function'), null);

  if v_touch_function is not null then
    execute format('select %s($1, $2)', v_touch_function)
    using v_object_id, v_actor_id;
  end if;

  perform api_utils.create_ok_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;

-- drop function api_utils.process_unsubscribe_message(integer, text, jsonb);

create or replace function api_utils.process_unsubscribe_message(in_client_id integer, in_request_id text, in_message jsonb)
returns void
volatile
as
$$
declare
  v_object_id integer := data.get_object_id(json.get_string(in_message, 'object_id'));
  v_actor_id integer;
  v_subscription_id integer;
  v_object jsonb;
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

  select id
  into v_subscription_id
  from data.client_subscriptions
  where
    object_id = v_object_id and
    client_id = in_client_id
  for update;

  if v_subscription_id is null then
    raise exception 'Client % has no subscription to object %', in_client_id, v_object_id;
  end if;

  delete from data.client_subscription_objects
  where client_subscription_id = v_subscription_id;

  delete from data.client_subscriptions
  where id = v_subscription_id;

  perform api_utils.create_ok_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;

-- drop function array_utils.is_unique(integer[]);

create or replace function array_utils.is_unique(in_array integer[])
returns boolean
immutable
as
$$
begin
  return intarray.uniq(intarray.sort(in_array)) = intarray.sort(in_array);
end;
$$
language plpgsql;

-- drop function array_utils.is_unique(text[]);

create or replace function array_utils.is_unique(in_array text[])
returns boolean
immutable
as
$$
declare
  v_sorted_unique text[];
  v_sorted text[];
begin
  if in_array is null then
    return null;
  end if;

  select coalesce(array_agg(v.value), array[]::text[])
  from (
    select distinct value
    from unnest(in_array) a(value)
    order by value
  ) v
  into v_sorted_unique;

  select coalesce(array_agg(v.value), array[]::text[])
  from (
    select value
    from unnest(in_array) a(value)
    order by value
  ) v
  into v_sorted;

  return v_sorted_unique = v_sorted;
end;
$$
language plpgsql;

-- drop function data.add_object_to_object(integer, integer, integer, text);

create or replace function data.add_object_to_object(in_object_id integer, in_parent_object_id integer, in_actor_id integer default null::integer, in_reason text default null::text)
returns void
volatile
as
$$
-- Как правило вместо этой функции следует вызывать data.change_object_groups
declare
  v_exists boolean;
  v_cycle boolean;
  v_row record;
begin
  assert data.is_instance(in_object_id);
  assert data.is_instance(in_parent_object_id);
  assert in_actor_id is null or data.is_instance(in_actor_id);

  if in_object_id = in_parent_object_id then
    raise exception 'Attempt to add object % to itself', in_object_id;
  end if;

  perform *
  from data.object_objects
  where
    (
      parent_object_id = in_parent_object_id and
      object_id = in_parent_object_id
    ) or
    (
      parent_object_id = in_object_id and
      object_id = in_object_id
    )
  for update;

  -- Блокируем эти записи, чтобы никто параллельно с нами не добавлял в ту же группу
  select true
  into v_exists
  from data.object_objects
  where
    parent_object_id = in_parent_object_id and
    object_id = in_object_id and
    intermediate_object_ids is null;

  if v_exists is not null then
    raise exception 'Connection from object % to object % already exists!', in_object_id, in_parent_object_id;
  end if;

  select true
  into v_cycle
  from data.object_objects
  where
    parent_object_id = in_object_id and
    object_id = in_parent_object_id;

  if v_cycle is not null then
    raise exception 'Cycle detected while adding object % to object %!', in_object_id, in_parent_object_id;
  end if;

  -- Блокируем parent'ы и child'ы на чтение, чтобы никто за это время не поменял нужные нам группы
  perform *
  from data.object_objects
  where
    id in (
      select oo.id
      from (
        select array_agg(os.value) as value
        from
        (
          select distinct(object_id) as value
          from data.object_objects
          where parent_object_id = in_object_id
        ) os
      ) o
      join (
        select array_agg(ps.value) as value
        from
        (
          select distinct(parent_object_id) as value
          from data.object_objects
          where object_id = in_parent_object_id
        ) ps
      ) po
      on true
      join data.object_objects oo
      on
        (
          (
            oo.parent_object_id = any(o.value) and
            oo.object_id = any(o.value)
          ) or
          (
            oo.parent_object_id = any(po.value) and
            oo.object_id = any(po.value)
          )
        ) and
        oo.intermediate_object_ids is null
    )
  for share;

  insert into data.object_objects(parent_object_id, object_id, intermediate_object_ids, start_reason, start_actor_id)
  select
    oo2.parent_object_id,
    oo1.object_id,
    oo1.intermediate_object_ids || in_object_id || in_parent_object_id || oo2.intermediate_object_ids,
    in_reason,
    in_actor_id
  from data.object_objects oo1
  join data.object_objects oo2
  on
    oo1.parent_object_id = in_object_id and
    oo1.object_id != oo1.parent_object_id and
    oo2.object_id = in_parent_object_id and
    oo2.object_id != oo2.parent_object_id
  union
  select
    oo.parent_object_id,
    in_object_id,
    in_parent_object_id || oo.intermediate_object_ids,
    in_reason,
    in_actor_id
  from data.object_objects oo
  where
    oo.object_id = in_parent_object_id and
    oo.object_id != oo.parent_object_id
  union
  select
    in_parent_object_id,
    oo.object_id,
    oo.intermediate_object_ids || in_object_id,
    in_reason,
    in_actor_id
  from data.object_objects oo
  where
    oo.parent_object_id = in_object_id and
    oo.object_id != oo.parent_object_id
  union
  select in_parent_object_id, in_object_id, null, in_reason, in_actor_id;
end;
$$
language plpgsql;

-- drop function data.attribute_change2jsonb(integer, jsonb);

create or replace function data.attribute_change2jsonb(in_attribute_id integer, in_value jsonb)
returns jsonb
immutable
as
$$
declare
  v_result jsonb;
begin
  assert in_attribute_id is not null;

  v_result := jsonb_build_object('id', in_attribute_id);

  if in_value is not null then
    v_result := v_result || jsonb_build_object('value', in_value);
  end if;

  return v_result;
end;
$$
language plpgsql;

-- drop function data.attribute_change2jsonb(integer, jsonb, integer);

create or replace function data.attribute_change2jsonb(in_attribute_id integer, in_value jsonb, in_value_object_id integer)
returns jsonb
immutable
as
$$
declare
  v_result jsonb;
begin
  assert in_attribute_id is not null;

  v_result := jsonb_build_object('id', in_attribute_id, 'value_object_id', in_value_object_id);

  if in_value is not null then
    v_result := v_result || jsonb_build_object('value', in_value);
  end if;

  return v_result;
end;
$$
language plpgsql;

-- drop function data.attribute_change2jsonb(integer, jsonb, text);

create or replace function data.attribute_change2jsonb(in_attribute_id integer, in_value jsonb, in_value_object_code text)
returns jsonb
stable
as
$$
begin
  return data.attribute_change2jsonb(in_attribute_id, in_value, data.get_object_id(in_value_object_code));
end;
$$
language plpgsql;

-- drop function data.attribute_change2jsonb(text, jsonb);

create or replace function data.attribute_change2jsonb(in_attribute_code text, in_value jsonb)
returns jsonb
stable
as
$$
begin
  return data.attribute_change2jsonb(data.get_attribute_id(in_attribute_code), in_value);
end;
$$
language plpgsql;

-- drop function data.attribute_change2jsonb(text, jsonb, integer);

create or replace function data.attribute_change2jsonb(in_attribute_code text, in_value jsonb, in_value_object_id integer)
returns jsonb
stable
as
$$
begin
  return data.attribute_change2jsonb(data.get_attribute_id(in_attribute_code), in_value, in_value_object_id);
end;
$$
language plpgsql;

-- drop function data.attribute_change2jsonb(text, jsonb, text);

create or replace function data.attribute_change2jsonb(in_attribute_code text, in_value jsonb, in_value_object_code text)
returns jsonb
stable
as
$$
begin
  return data.attribute_change2jsonb(data.get_attribute_id(in_attribute_code), in_value, data.get_object_id(in_value_object_code));
end;
$$
language plpgsql;

-- drop function data.calc_content_diff(jsonb, jsonb);

create or replace function data.calc_content_diff(in_original_content jsonb, in_new_content jsonb)
returns jsonb
immutable
as
$$
-- add - массив объектов с полями position и object_code, position может отсутствовать
-- remove - массив кодов объектов
declare
  v_add jsonb := jsonb '[]';
  v_remove jsonb := jsonb '[]';
  v_code jsonb;
begin
  assert in_original_content is null or json.is_string_array(in_original_content);
  assert in_new_content is null or json.is_string_array(in_new_content);

  if
    in_original_content is null and in_new_content is null or
    in_original_content = in_new_content
  then
    return jsonb '{"add": [], "remove": []}';
  end if;

  if in_new_content is null or in_new_content = jsonb '[]' then
    v_remove := coalesce(in_original_content, jsonb '[]');
  elsif in_original_content is null or in_original_content = '[]' then
    for v_code in
    (
      select value
      from jsonb_array_elements(in_new_content)
    )
    loop
      v_add := v_add || jsonb_build_object('object_code', v_code);
    end loop;
  else
    declare
      v_original_idx integer := 0;
      v_original_size integer := jsonb_array_length(in_original_content);
      v_new_idx integer := 0;
      v_new_size integer := jsonb_array_length(in_new_content);
      v_current_original_value jsonb;
      v_current_new_value jsonb;
      v_original_test_idx integer;
      v_new_test_idx integer;
      v_remove_indexes integer[];
      v_modified_content jsonb := in_original_content;
    begin
      -- Сначала определим, что нужно удалить
      while v_original_idx != v_original_size and v_new_idx != v_new_size loop
        v_current_original_value := in_original_content->v_original_idx;
        v_current_new_value := in_new_content->v_new_idx;

        if v_current_original_value = v_current_new_value then
          v_original_idx := v_original_idx + 1;
          v_new_idx := v_new_idx + 1;
        else
          v_original_test_idx :=
            json.array_find(in_original_content, v_current_new_value, v_original_idx + 1);
          v_new_test_idx :=
            json.array_find(in_new_content, v_current_original_value, v_new_idx + 1);

          -- Определяем, что эффективнее - удалять объекты из оригинального массива или добавлять в результирующий
          if v_original_test_idx is not null and v_new_test_idx is not null then
            if v_original_test_idx - v_original_idx <= v_new_test_idx - v_new_idx then
              -- Удаляем
              while v_original_idx != v_original_test_idx loop
                v_remove_indexes := array_prepend(v_original_idx, v_remove_indexes);
                v_remove := v_remove || (in_original_content->v_original_idx);
                v_original_idx := v_original_idx + 1;
              end loop;

              v_original_idx := v_original_idx + 1;
              v_new_idx := v_new_idx + 1;
            else
              v_original_idx := v_original_idx + 1;
              v_new_idx := v_new_test_idx + 1;
            end if;
          elsif v_original_test_idx is null then
            v_new_idx := v_new_idx + 1;
          else
            v_remove_indexes := array_prepend(v_original_idx, v_remove_indexes);
            v_remove := v_remove || (in_original_content->v_original_idx);
            v_original_idx := v_original_idx + 1;
          end if;
        end if;
      end loop;

      while v_original_idx != v_original_size loop
        v_remove_indexes := array_prepend(v_original_idx, v_remove_indexes);
        v_remove := v_remove || (in_original_content->v_original_idx);
        v_original_idx := v_original_idx + 1;
      end loop;

      -- Потом удалим из оригинального массива всё, что решили удалять
      for v_original_idx in
        select value
        from unnest(v_remove_indexes) a(value)
      loop
        v_modified_content := v_modified_content - v_original_idx;
      end loop;

      -- Теперь сгенерируем добавления
      v_new_idx := 0;
      v_original_size := jsonb_array_length(v_modified_content);

      if v_new_size = v_original_size then
        v_new_idx := v_new_size;
      elsif v_original_size > 0 then
        v_original_idx := 0;

        loop
          v_current_original_value := v_modified_content->v_original_idx;
          v_current_new_value := in_new_content->v_new_idx;

          if v_current_original_value = v_current_new_value then
            v_original_idx := v_original_idx + 1;
            v_new_idx := v_new_idx + 1;

            assert v_new_idx != v_new_size;

            if v_original_idx = v_original_size then
              exit;
            end if;
          else
            v_add :=
              v_add ||
              jsonb_build_object('position', v_current_original_value, 'object_code', v_current_new_value);
            v_new_idx := v_new_idx + 1;

            if v_new_size - v_new_idx = v_original_size - v_original_idx then
              v_new_idx := v_new_size;
              exit;
            end if;
          end if;
        end loop;
      end if;

      while v_new_idx != v_new_size loop
        v_add :=
          v_add ||
          jsonb_build_object('object_code', in_new_content->v_new_idx);
        v_new_idx := v_new_idx + 1;
      end loop;
    end;
  end if;

  return jsonb_build_object('add', v_add, 'remove', v_remove);
end;
$$
language plpgsql;

-- drop function data.can_attribute_be_overridden(integer);

create or replace function data.can_attribute_be_overridden(in_attribute_id integer)
returns boolean
stable
as
$$
declare
  v_ret_val boolean;
begin
  select can_be_overridden
  into v_ret_val
  from data.attributes
  where id = in_attribute_id;

  if v_ret_val is null then
    raise exception 'Attribute % was not found', in_attribute_id;
  end if;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function data.change_current_object(integer, text, integer, jsonb, text);

create or replace function data.change_current_object(in_client_id integer, in_request_id text, in_object_id integer, in_changes jsonb, in_reason text default null::text)
returns boolean
volatile
as
$$
-- Функция возвращает, отправляли ли сообщение клиенту in_client_id
-- Если функция вернула false, то скорее всего внешнему коду нужно сгенерировать событие ok или action
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
begin
  assert in_changes is not null;

  return data.process_diffs_and_notify_current_object(
    data.change_object(in_object_id, in_changes, v_actor_id, in_reason),
    in_client_id,
    in_request_id,
    in_object_id);
end;
$$
language plpgsql;

-- drop function data.change_object(integer, jsonb, integer, text);

create or replace function data.change_object(in_object_id integer, in_changes jsonb, in_actor_id integer default null::integer, in_reason text default null::text)
returns jsonb
volatile
as
$$
-- У параметра in_changes есть два возможных формата:
-- 1. Только для установки значения: объект, где ключ - код атрибута, а значение - значение атрибута
-- 2. Массив объектов с полями id или code, value_object_id, или value_object_code, value
-- Если присутствует value_object_id или value_object_code, то изменится именно значение, задаваемое для указанного объекта
-- Если value отсутствует (именно отсутствует, а не равно jsonb 'null'!), то указанное значение удаляется, в противном случае - устанавливается

-- Возвращается массив объектов с полями object_id, client_id, object и list_changes, поля object и list_changes могут отсутствовать
declare
  v_changes jsonb := data.filter_changes(in_object_id, data.preprocess_changes_with_codes(in_changes));
  v_object_code text;

  v_subscriptions jsonb := jsonb '[]';
  v_subscription_objects jsonb := jsonb '[]';
  v_actor_subscriptions jsonb := jsonb '[]';

  v_set_visible integer[];
  v_set_invisible integer[];

  v_ret_val jsonb := jsonb '[]';
begin
  assert in_actor_id is null or data.is_instance(in_actor_id);

  if v_changes = jsonb '[]' then
    return jsonb '[]';
  end if;

  v_object_code := data.get_object_code(in_object_id);

  -- Сохраним атрибуты и действия для всех клиентов, подписанных на получение изменений данного объекта
  declare
    v_ids integer[];
  begin
    select array_agg(id)
    into v_ids
    from data.client_subscriptions
    where object_id = in_object_id;

    v_subscriptions := data_internal.save_state(v_ids, null);
  end;

  -- Сохраним состояние миникарточек в списках, в которые входит данный объект
  declare
    v_list record;
    v_actor_id integer;
    v_subscription_object jsonb;
  begin
    for v_list in
    (
      select
        cso.id,
        cs.client_id,
        cs.object_id,
        cso.is_visible,
        cso.index
      from data.client_subscription_objects cso
      join data.client_subscriptions cs
        on cs.id = cso.client_subscription_id
      where cso.object_id = in_object_id
    )
    loop
      v_actor_id := data.get_active_actor_id(v_list.client_id);

      v_subscription_object :=
        jsonb_build_object(
          'id',
          v_list.id,
          'client_id',
          v_list.client_id,
          'actor_id',
          v_actor_id,
          'object_id',
          v_list.object_id,
          'is_visible',
          v_list.is_visible,
          'index',
          v_list.index);

      if v_list.is_visible then
        -- Изменения невидимых объектов должны были пройти через change_object, атрибут в таблице client_subscription_objects был бы изменён
        assert json.get_boolean(data.get_attribute_value(in_object_id, 'is_visible', v_actor_id));

        v_subscription_object :=
          v_subscription_object ||
            jsonb_build_object('data', data.get_object(in_object_id, v_actor_id, 'mini', v_list.object_id));
      end if;

      v_subscription_objects := v_subscription_objects || v_subscription_object;
    end loop;
  end;

  -- Если изменяется актор, то сохраняем подписки его клиентов
  declare
    v_ids integer[];
  begin
    select array_agg(id)
    into v_ids
    from data.client_subscriptions
    where
      client_id in (
        select id
        from data.clients
        where actor_id = in_object_id) and
      object_id != in_object_id;

    v_actor_subscriptions := data_internal.save_state(v_ids, in_object_id);
  end;

  -- Меняем состояние объекта
  declare
    v_change record;
  begin
    for v_change in
    (
      select
        json.get_integer(value, 'id') as attribute_id,
        json.get_integer_opt(value, 'value_object_id', null) as value_object_id,
        value->'value' as value
      from jsonb_array_elements(v_changes)
    )
    loop
      if v_change.value is null then
        perform data.delete_attribute_value(
          in_object_id,
          v_change.attribute_id,
          v_change.value_object_id,
          in_actor_id,
          in_reason);
      else
        perform data.set_attribute_value(
          in_object_id,
          v_change.attribute_id,
          v_change.value,
          v_change.value_object_id,
          in_actor_id,
          in_reason);
      end if;
    end loop;
  end;

  -- Берём новые атрибуты и действия для тех же клиентов
  v_ret_val := v_ret_val || data_internal.process_saved_state(v_subscriptions);

  -- Берём новые миникарточки для тех же списков
  if v_subscription_objects != jsonb '[]' then
    declare
      v_mini_card_function text := json.get_string_opt(data.get_attribute_value(in_object_id, 'mini_card_function'), null);
      v_list record;
      v_new_data jsonb;
      v_attributes jsonb;
      v_actions jsonb;
      v_position_object_id integer;
      v_add jsonb;
      v_subscription_object_code text;
    begin
      for v_list in
      (
        select
          json.get_integer(value, 'id') as id,
          json.get_integer(value, 'client_id') as client_id,
          json.get_integer(value, 'actor_id') as actor_id,
          json.get_integer(value, 'object_id') as object_id,
          json.get_boolean(value, 'is_visible') as is_visible,
          json.get_integer(value, 'index') as index,
          json.get_object_opt(value, 'data', null) as data
        from jsonb_array_elements(v_subscription_objects)
      )
      loop
        if v_mini_card_function is not null then
          execute format('select %s($1, $2)', v_mini_card_function)
          using in_object_id, v_list.actor_id;
        end if;

        if not json.get_boolean_opt(data.get_attribute_value(in_object_id, 'is_visible', v_list.actor_id), false) then
          if v_list.is_visible then
            v_set_invisible := array_append(v_set_invisible, v_list.id);

            v_ret_val :=
              v_ret_val ||
              jsonb_build_object(
                'object_id',
                data.get_object_code(v_list.object_id),
                'client_id',
                v_list.client_id,
                'list_changes',
                jsonb_build_object('remove', jsonb_build_array(v_object_code)));
          end if;
        else
          v_new_data := data.get_object(in_object_id, v_list.actor_id, 'mini', v_list.object_id);

          if not v_list.is_visible or v_new_data != v_list.data then
            v_subscription_object_code := data.get_object_code(v_list.object_id);

            if not v_list.is_visible then
              v_set_visible := array_append(v_set_visible, v_list.id);

              v_add := jsonb_build_object('object', v_new_data);

              select s.value
              into v_position_object_id
              from (
                select first_value(object_id) over(order by index) as value
                from data.client_subscription_objects
                where
                  client_subscription_id in (
                    select client_subscription_id
                    from data.client_subscription_objects
                    where id = v_list.id) and
                  index > v_list.index and
                  is_visible is true
              ) s
              limit 1;

              if v_position_object_id is not null then
                v_add := v_add || jsonb_build_object('position', data.get_object_code(v_position_object_id));
              end if;

              v_ret_val :=
                v_ret_val ||
                jsonb_build_object(
                  'object_id',
                  v_subscription_object_code,
                  'client_id',
                  v_list.client_id,
                  'list_changes',
                  jsonb_build_object(
                    'add',
                    jsonb_build_array(v_add)));
            else
              v_ret_val :=
                v_ret_val ||
                jsonb_build_object(
                  'object_id',
                  v_subscription_object_code,
                  'client_id',
                  v_list.client_id,
                  'list_changes',
                  jsonb_build_object('change', jsonb_build_array(v_new_data)));
            end if;
          end if;
        end if;
      end loop;
    end;
  end if;

  -- И обрабатываем изменения подписок клиентов изменённого актора
  v_ret_val := v_ret_val || data_internal.process_saved_state(v_actor_subscriptions);

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function data.change_object_and_notify(integer, jsonb, integer, text);

create or replace function data.change_object_and_notify(in_object_id integer, in_changes jsonb, in_actor_id integer default null::integer, in_reason text default null::text)
returns void
volatile
as
$$
begin
  perform data.process_diffs_and_notify(data.change_object(in_object_id, in_changes, in_actor_id, in_reason));
end;
$$
language plpgsql;

-- drop function data.change_object_groups(integer, integer[], integer[], integer, text);

create or replace function data.change_object_groups(in_object_id integer, in_add integer[], in_remove integer[], in_actor_id integer, in_reason text default null::text)
returns jsonb
volatile
as
$$
-- В параметре in_add приходит массив объектов, в которые нужно добавить объект
-- В параметре in_remove приходит массив объектов, из которых нужно убрать объект

-- Возвращается массив объектов с полями object_id, client_id, object и list_changes, поля object и list_changes могут отсутствовать
declare
  v_parent_object_id integer;
  v_actor_subscriptions jsonb := jsonb '[]';
  v_ret_val jsonb := jsonb '[]';
begin
  assert coalesce(array_length(in_add, 1), 0) + coalesce(array_length(in_remove, 1), 0) > 0;

  -- Сохраняем подписки клиентов актора
  declare
    v_subscription record;
    v_list record;
    v_list_objects jsonb;
    v_list_object jsonb;
  begin
    for v_subscription in
    (
      select
        id,
        object_id,
        client_id
      from data.client_subscriptions
      where
        client_id in (
          select id
          from data.clients
          where actor_id = in_object_id)
    )
    loop
      v_list_objects := jsonb '[]';

      for v_list in
      (
        select
          id,
          object_id,
          is_visible,
          index
        from data.client_subscription_objects
        where client_subscription_id = v_subscription.id
      )
      loop
        v_list_object :=
          jsonb_build_object(
            'id',
            v_list.id,
            'object_id',
            v_list.object_id,
            'is_visible',
            v_list.is_visible,
            'index',
            v_list.index);

        if v_list.is_visible then
          v_list_object :=
            v_list_object ||
              jsonb_build_object(
                'data',
                data.get_object(v_list.object_id, in_object_id, 'mini', v_subscription.object_id));
        end if;

        v_list_objects := v_list_objects || v_list_object;
      end loop;

      v_actor_subscriptions :=
        v_actor_subscriptions ||
        jsonb_build_object(
          'id',
          v_subscription.id,
          'client_id',
          v_subscription.client_id,
          'object_id',
          v_subscription.object_id,
          'data',
          data.get_object(v_subscription.object_id, in_object_id, 'full', v_subscription.object_id),
          'list_objects',
          v_list_objects);
    end loop;
  end;

  -- Меняем группы объектов
  for v_parent_object_id in
  (
    select value
    from unnest(in_add) a(value)
  )
  loop
    perform data.add_object_to_object(in_object_id, v_parent_object_id, in_actor_id, in_reason);
  end loop;

  for v_parent_object_id in
  (
    select value
    from unnest(in_remove) a(value)
  )
  loop
    perform data.remove_object_from_object(in_object_id, v_parent_object_id, in_actor_id, in_reason);
  end loop;

  -- Обрабатываем изменения подписок клиентов изменённого актора
  if v_actor_subscriptions != jsonb '[]' then
    declare
      v_subscription record;
      v_full_card_function text;
      v_subscription_object_code text;
      v_new_data jsonb;
      v_object jsonb;
      v_list_changes jsonb;
      v_ret_val_element jsonb;
      v_set_visible integer[];
      v_set_invisible integer[];
    begin
      for v_subscription in
      (
        select
          json.get_integer(value, 'id') as id,
          json.get_integer(value, 'client_id') as client_id,
          json.get_integer(value, 'object_id') as object_id,
          json.get_object(value, 'data') as data,
          json.get_array(value, 'list_objects') as list_objects
        from jsonb_array_elements(v_actor_subscriptions)
      )
      loop
        v_full_card_function :=
          json.get_string_opt(
            data.get_attribute_value(v_subscription.object_id, 'full_card_function'),
            null);

        if v_full_card_function is not null then
          execute format('select %s($1, $2)', v_full_card_function)
          using v_subscription.object_id, in_object_id;
        end if;

        v_subscription_object_code := data.get_object_code(v_subscription.object_id);

        -- Объект стал невидимым - отправляем специальный diff и вычищаем подписки
        if not json.get_boolean_opt(data.get_attribute_value(v_subscription.object_id, 'is_visible', in_object_id), false) then
          v_ret_val :=
            v_ret_val ||
            jsonb_build_object(
              'object_id',
              v_subscription_object_code,
              'client_id',
              v_subscription.client_id,
              'object',
              jsonb 'null');

          delete from data.client_subscription_objects
          where client_subscription_id = v_subscription.id;

          delete from data.client_subscriptions
          where id = v_subscription.id;

          continue;
        end if;

        v_new_data := data.get_object(v_subscription.object_id, in_object_id, 'full', v_subscription.object_id);

        v_object := null;
        v_list_changes := jsonb '{}';

        -- Сравниваем и при нахождении различий включаем в diff
        if v_new_data != v_subscription.data then
          v_object := v_new_data;
        end if;

        if v_subscription.list_objects != jsonb '[]' then
          declare
            v_list record;
            v_mini_card_function text;
            v_new_list_data jsonb;
            v_add jsonb;
            v_position_object_id integer;
          begin
            for v_list in
            (
              select
                json.get_integer(value, 'id') as id,
                json.get_integer(value, 'object_id') as object_id,
                json.get_boolean(value, 'is_visible') as is_visible,
                json.get_integer(value, 'index') as index,
                json.get_object_opt(value, 'data', null) as data
              from jsonb_array_elements(v_subscription.list_objects)
            )
            loop
              v_mini_card_function :=
                json.get_string_opt(
                  data.get_attribute_value(v_list.object_id, 'mini_card_function'),
                  null);

              if v_mini_card_function is not null then
                execute format('select %s($1, $2)', v_mini_card_function)
                using v_list.object_id, in_object_id;
              end if;

              if not json.get_boolean_opt(data.get_attribute_value(v_list.object_id, 'is_visible', in_object_id), false) then
                if v_list.is_visible then
                  v_set_invisible := array_append(v_set_invisible, v_list.id);

                  v_ret_val :=
                    v_ret_val ||
                    jsonb_build_object(
                      'object_id',
                      v_subscription_object_code,
                      'client_id',
                      v_subscription.client_id,
                      'list_changes',
                      jsonb_build_object('remove', jsonb_build_array(data.get_object_code(v_list.object_id))));
                end if;
              else
                v_new_list_data := data.get_object(v_list.object_id, in_object_id, 'mini', v_subscription.object_id);

                if not v_list.is_visible or v_new_list_data != v_list.data then
                  if not v_list.is_visible then
                    v_set_visible := array_append(v_set_visible, v_list.id);

                    v_add := jsonb_build_object('object', v_new_list_data);

                    select s.value
                    into v_position_object_id
                    from (
                      select first_value(object_id) over(order by index) as value
                      from data.client_subscription_objects
                      where
                        client_subscription_id = v_subscription.id and
                        index > v_list.index and
                        is_visible is true
                    ) s
                    limit 1;

                    if v_position_object_id is not null then
                      v_add := v_add || jsonb_build_object('position', data.get_object_code(v_position_object_id));
                    end if;

                    v_ret_val :=
                      v_ret_val ||
                      jsonb_build_object(
                        'object_id',
                        v_subscription_object_code,
                        'client_id',
                        v_subscription.client_id,
                        'list_changes',
                        jsonb_build_object(
                          'add',
                          jsonb_build_array(v_add)));
                  else
                    v_ret_val :=
                      v_ret_val ||
                      jsonb_build_object(
                        'object_id',
                        v_subscription_object_code,
                        'client_id',
                        v_subscription.client_id,
                        'list_changes',
                        jsonb_build_object('change', jsonb_build_array(v_new_list_data)));
                  end if;
                end if;
              end if;
            end loop;
          end;
        end if;

        if v_object is not null or v_list_changes != jsonb '{}' then
          v_ret_val_element := jsonb_build_object('object_id', v_subscription_object_code, 'client_id', v_subscription.client_id);

          if v_object is not null then
            v_ret_val_element := v_ret_val_element || jsonb_build_object('object', v_object);
          end if;

          if v_list_changes!= jsonb '{}' then
            v_ret_val_element := v_ret_val_element || jsonb_build_object('list_changes', v_list_changes);
          end if;

          v_ret_val := v_ret_val || v_ret_val_element;
        end if;
      end loop;

      if v_set_visible is not null then
        update data.client_subscription_objects
        set is_visible = true
        where id = any(v_set_visible);
      end if;

      if v_set_invisible is not null then
        update data.client_subscription_objects
        set is_visible = false
        where id = any(v_set_invisible);
      end if;
    end;
  end if;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function data.create_class(text, jsonb);

create or replace function data.create_class(in_code text, in_attributes jsonb)
returns integer
volatile
as
$$
-- У параметра in_changes есть два возможных формата:
-- 1. Объект, где ключ - код атрибута, а значение - значение атрибута
-- 2. Массив объектов с полями id или code, value_object_id, или value_object_code, value
declare
  v_attributes jsonb := data.preprocess_changes_with_codes(in_attributes);
  v_class_id integer;
  v_attribute record;
begin
  assert in_code is not null;

  insert into data.objects(code, type)
  values(in_code, 'class')
  returning id into v_class_id;

  for v_attribute in
  (
    select
      json.get_integer(value, 'id') id,
      json.get_integer_opt(value, 'value_object_id', null) value_object_id,
      value->'value' as value
    from jsonb_array_elements(v_attributes)
  )
  loop
    insert into data.attribute_values(object_id, attribute_id, value, value_object_id)
    values(v_class_id, v_attribute.id, v_attribute.value, v_attribute.value_object_id);
  end loop;

  return v_class_id;
end;
$$
language plpgsql;

-- drop function data.create_job(timestamp with time zone, text, jsonb);

create or replace function data.create_job(in_desired_time timestamp with time zone, in_function text, in_params jsonb)
returns void
volatile
as
$$
declare
  v_min_time timestamp with time zone;
begin
  assert in_desired_time is not null;
  assert in_function is not null;

  insert into data.jobs(desired_time, function, params)
  values(in_desired_time, in_function, in_params);

  select min(desired_time)
  into v_min_time
  from data.jobs;

  if v_min_time = in_desired_time then
    perform api_utils.create_job_notification(in_desired_time);
  end if;
end;
$$
language plpgsql;

-- drop function data.create_object(text, jsonb, text, text[]);

create or replace function data.create_object(in_code text, in_attributes jsonb, in_class_code text default null::text, in_groups text[] default null::text[])
returns integer
volatile
as
$$
-- У параметра in_changes есть два возможных формата:
-- 1. Объект, где ключ - код атрибута, а значение - значение атрибута
-- 2. Массив объектов с полями id или code, value_object_id, или value_object_code, value
declare
  v_attributes jsonb;
  v_object_id integer;
  v_attribute record;
  v_group_code text;
begin
  if in_code is null then
    insert into data.objects(class_id)
    values(case when in_class_code is not null then data.get_class_id(in_class_code) else null end)
    returning id into v_object_id;
  else
    insert into data.objects(code, class_id)
    values(in_code, case when in_class_code is not null then data.get_class_id(in_class_code) else null end)
    returning id into v_object_id;
  end if;

  v_attributes := data.preprocess_changes_with_codes(in_attributes);

  for v_attribute in
  (
    select
      json.get_integer(value, 'id') id,
      json.get_integer_opt(value, 'value_object_id', null) value_object_id,
      value->'value' as value
    from jsonb_array_elements(v_attributes)
  )
  loop
    insert into data.attribute_values(object_id, attribute_id, value, value_object_id)
    values(v_object_id, v_attribute.id, v_attribute.value, v_attribute.value_object_id);
  end loop;

  for v_group_code in
  (
    select value
    from unnest(in_groups) a(value)
  )
  loop
    perform data.add_object_to_object(v_object_id, data.get_object_id(v_group_code));
  end loop;

  return v_object_id;
end;
$$
language plpgsql;

-- drop function data.delete_attribute_value(integer, integer, integer, integer, text);

create or replace function data.delete_attribute_value(in_object_id integer, in_attribute_id integer, in_value_object_id integer, in_actor_id integer, in_reason text default null::text)
returns void
volatile
as
$$
-- Как правило вместо этой функции следует вызывать data.change_object
-- Эта функция не проставляет правильно блокировки и не рассылает уведомлений
declare
  v_attribute_value_id integer;
begin
  assert data.is_instance(in_object_id);
  assert in_attribute_id is not null;
  assert in_actor_id is null or data.is_instance(in_actor_id);

  if in_value_object_id is null then
    select id
    into v_attribute_value_id
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id is null;
  else
    select id
    into v_attribute_value_id
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id = in_value_object_id;
  end if;

  assert v_attribute_value_id is not null;

  insert into data.attribute_values_journal(object_id, attribute_id, value_object_id, value, start_time, start_reason, start_actor_id, end_time, end_reason, end_actor_id)
  select object_id, attribute_id, value_object_id, value, start_time, start_reason, start_actor_id, clock_timestamp(), in_reason, in_actor_id
  from data.attribute_values
  where id = v_attribute_value_id;

  delete from data.attribute_values
  where id = v_attribute_value_id;
end;
$$
language plpgsql;

-- drop function data.filter_changes(integer, jsonb);

create or replace function data.filter_changes(in_object_id integer, in_changes jsonb)
returns jsonb
volatile
as
$$
declare
  v_change record;
  v_filtered_changes jsonb := jsonb '[]';
  v_id integer;
  v_value jsonb;
  v_next_change jsonb;
begin
  assert data.is_instance(in_object_id);
  assert json.is_object_array(in_changes);

  for v_change in
  (
    select
      json.get_integer(value, 'id') as id,
      json.get_integer_opt(value, 'value_object_id', null) as value_object_id,
      value->'value' as value
    from jsonb_array_elements(in_changes)
  )
  loop
    if v_change.value is null then
      if v_change.value_object_id is null then
        select id
        into v_id
        from data.attribute_values
        where
          object_id = in_object_id and
          attribute_id = v_change.id and
          value_object_id is null
        for update;
      else
        select id
        into v_id
        from data.attribute_values
        where
          object_id = in_object_id and
          attribute_id = v_change.id and
          value_object_id = v_change.value_object_id
        for update;
      end if;

      -- Удалять нечего
      if v_id is null then
        continue;
      end if;
    else
      v_value := data.get_raw_attribute_value_for_update(in_object_id, v_change.id, v_change.value_object_id);

      -- Уже то же значение
      if v_change.value = v_value then
        continue;
      end if;
    end if;

    v_next_change := jsonb_build_object('id', v_change.id);
    if v_change.value_object_id is not null then
      v_next_change := v_next_change || jsonb_build_object('value_object_id', v_change.value_object_id);
    end if;
    if v_change.value is not null then
      v_next_change := v_next_change || jsonb_build_object('value', v_change.value);
    end if;

    v_filtered_changes := v_filtered_changes || v_next_change;
  end loop;

  return v_filtered_changes;
end;
$$
language plpgsql;

-- drop function data.filter_template(jsonb, jsonb, jsonb);

create or replace function data.filter_template(in_template jsonb, in_attributes jsonb, in_actions jsonb)
returns jsonb
immutable
as
$$
declare
  v_groups jsonb := json.get_array(json.get_object(in_template), 'groups');
  v_group jsonb;
  v_attribute_code text;
  v_attribute jsonb;
  v_attribute_name text;
  v_attribute_value text;
  v_attribute_value_description text;
  v_action_name text;
  v_name text;
  v_filtered_group jsonb;
  v_filtered_groups jsonb[] := array[]::jsonb[];
  v_filtered_attributes text[];
  v_filtered_actions text[];
  v_title text;
  v_subtitle text;
  v_ret_val jsonb;
begin
  assert json.get_object(in_attributes) is not null;

  for v_group in
    select value
    from jsonb_array_elements(v_groups)
  loop
    -- Фильтруем атрибуты
    v_filtered_attributes := null;

    if v_group ? 'attributes' then
      for v_attribute_code in
        select json.get_string(value)
        from jsonb_array_elements(json.get_array(v_group, 'attributes'))
      loop
        v_attribute := json.get_object_opt(in_attributes, v_attribute_code, null);

        if v_attribute is not null then
          -- Отфильтровываем атрибуты без имени, значения и описания значения
          v_attribute_name := json.get_string_opt(v_attribute, 'name', null);
          v_attribute_value := v_attribute->'value';
          v_attribute_value_description := json.get_string_opt(v_attribute, 'value_description', null);

          if v_attribute_name is not null or v_attribute_value is not null or v_attribute_value_description is not null then
            assert not data.is_hidden_attribute(data.get_attribute_id(v_attribute_code));

            v_filtered_attributes := array_append(v_filtered_attributes, v_attribute_code);
          end if;
        end if;
      end loop;
    end if;

    -- Фильтруем действия
    v_filtered_actions := null;
    if v_group ? 'actions' then
      for v_action_name in
        select json.get_string(value)
        from jsonb_array_elements(json.get_array(v_group, 'actions'))
      loop
        if in_actions ? v_action_name then
          v_filtered_actions := array_append(v_filtered_actions, v_action_name);
        end if;
      end loop;
    end if;

    -- Собираем новую группу
    if v_filtered_attributes is not null or v_filtered_actions is not null then
      v_name = json.get_string_opt(v_group, 'name', null);

      v_filtered_group := jsonb '{}';
      if v_name is not null then
        v_filtered_group := v_filtered_group || jsonb_build_object('name', v_name);
      end if;
      if v_filtered_attributes is not null then
        v_filtered_group := v_filtered_group || jsonb_build_object('attributes', to_jsonb(v_filtered_attributes));
      end if;
      if v_filtered_actions is not null then
        v_filtered_group := v_filtered_group || jsonb_build_object('actions', to_jsonb(v_filtered_actions));
      end if;

      v_filtered_groups := array_append(v_filtered_groups, v_filtered_group);
    end if;
  end loop;

  v_ret_val := jsonb_build_object('groups', to_jsonb(v_filtered_groups));

  if in_template ? 'title' then
    v_title := json.get_string(in_template, 'title');

    if in_attributes ? v_title then
      v_ret_val := v_ret_val || jsonb_build_object('title', v_title);
    end if;
  end if;

  if in_template ? 'subtitle' then
    v_subtitle := json.get_string(in_template, 'subtitle');

    if in_attributes ? v_subtitle then
      v_ret_val := v_ret_val || jsonb_build_object('subtitle', v_subtitle);
    end if;
  end if;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function data.get_active_actor_id(integer);

create or replace function data.get_active_actor_id(in_client_id integer)
returns integer
stable
as
$$
declare
  v_actor_id integer;
begin
  assert in_client_id is not null;

  select actor_id
  into v_actor_id
  from data.clients
  where id = in_client_id;

  assert v_actor_id is not null;

  return v_actor_id;
end;
$$
language plpgsql;

-- drop function data.get_array_param(text);

create or replace function data.get_array_param(in_code text)
returns jsonb
stable
as
$$
begin
  assert in_code is not null;

  return
    json.get_array(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not an array', in_code;
end;
$$
language plpgsql;

-- drop function data.get_attribute_code(integer);

create or replace function data.get_attribute_code(in_attribute_id integer)
returns text
stable
as
$$
declare
  v_attribute_code text;
begin
  assert in_attribute_id is not null;

  select code
  into v_attribute_code
  from data.attributes
  where id = in_attribute_id;

  if v_attribute_code is null then
    raise exception 'Can''t find attribute "%"', in_attribute_id;
  end if;

  return v_attribute_code;
end;
$$
language plpgsql;

-- drop function data.get_attribute_id(text);

create or replace function data.get_attribute_id(in_attribute_code text)
returns integer
stable
as
$$
declare
  v_attribute_id integer;
begin
  assert in_attribute_code is not null;

  select id
  into v_attribute_id
  from data.attributes
  where code = in_attribute_code;

  if v_attribute_id is null then
    raise exception 'Can''t find attribute "%"', in_attribute_code;
  end if;

  return v_attribute_id;
end;
$$
language plpgsql;

-- drop function data.get_attribute_value(integer, integer);

create or replace function data.get_attribute_value(in_object_id integer, in_attribute_id integer)
returns jsonb
stable
as
$$
declare
  v_attribute_value jsonb;
  v_class_id integer;
begin
  assert data.is_instance(in_object_id);
  assert not data.can_attribute_be_overridden(in_attribute_id);

  select value
  into v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    value_object_id is null;

  if v_attribute_value is null then
    v_class_id := data.get_object_class_id(in_object_id);

    if v_class_id is not null then
      select value
      into v_attribute_value
      from data.attribute_values
      where
        object_id = v_class_id and
        attribute_id = in_attribute_id and
        value_object_id is null;
    end if;
  end if;

  return v_attribute_value;
end;
$$
language plpgsql;

-- drop function data.get_attribute_value(integer, integer, integer);

create or replace function data.get_attribute_value(in_object_id integer, in_attribute_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_priority_attribute_id integer := data.get_attribute_id('priority');
  v_attribute_value jsonb;
  v_class_id integer;
begin
  assert data.is_instance(in_object_id);
  assert in_actor_id is null or data.is_instance(in_actor_id);
  assert data.can_attribute_be_overridden(in_attribute_id);

  select av.value
  into v_attribute_value
  from data.attribute_values av
  left join data.object_objects oo on
    av.value_object_id = oo.parent_object_id and
    oo.object_id = in_actor_id
  left join data.attribute_values pr on
    pr.object_id = oo.parent_object_id and
    pr.attribute_id = v_priority_attribute_id and
    pr.value_object_id is null
  left join data.objects o on
    o.id = oo.parent_object_id and
    pr.id is null
  left join data.attribute_values pr2 on
    pr2.object_id = o.class_id and
    pr2.attribute_id = v_priority_attribute_id and
    pr2.value_object_id is null
  where
    (av.object_id = in_object_id or av.object_id = data.get_object_class_id(in_object_id)) and
    av.attribute_id = in_attribute_id and
    (
      av.value_object_id is null or
      oo.id is not null
    )
  order by greatest(json.get_integer_opt(pr.value, 0), json.get_integer_opt(pr2.value, 0)) desc, data.is_instance(av.object_id) desc
  limit 1;

  return v_attribute_value;
end;
$$
language plpgsql;

-- drop function data.get_attribute_value(integer, text);

create or replace function data.get_attribute_value(in_object_id integer, in_attribute_code text)
returns jsonb
stable
as
$$
begin
  return data.get_attribute_value(in_object_id, data.get_attribute_id(in_attribute_code));
end;
$$
language plpgsql;

-- drop function data.get_attribute_value(integer, text, integer);

create or replace function data.get_attribute_value(in_object_id integer, in_attribute_code text, in_actor_id integer)
returns jsonb
stable
as
$$
begin
  return data.get_attribute_value(in_object_id, data.get_attribute_id(in_attribute_code), in_actor_id);
end;
$$
language plpgsql;

-- drop function data.get_attribute_value(text, integer);

create or replace function data.get_attribute_value(in_object_code text, in_attribute_id integer)
returns jsonb
stable
as
$$
begin
  return data.get_attribute_value(data.get_object_id(in_object_code), in_attribute_id);
end;
$$
language plpgsql;

-- drop function data.get_attribute_value(text, integer, integer);

create or replace function data.get_attribute_value(in_object_code text, in_attribute_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
begin
  return data.get_attribute_value(data.get_object_id(in_object_code), in_attribute_id, in_actor_id);
end;
$$
language plpgsql;

-- drop function data.get_attribute_value(text, text);

create or replace function data.get_attribute_value(in_object_code text, in_attribute_code text)
returns jsonb
stable
as
$$
begin
  return data.get_attribute_value(data.get_object_id(in_object_code), data.get_attribute_id(in_attribute_code));
end;
$$
language plpgsql;

-- drop function data.get_attribute_value(text, text, integer);

create or replace function data.get_attribute_value(in_object_code text, in_attribute_code text, in_actor_id integer)
returns jsonb
stable
as
$$
begin
  return data.get_attribute_value(data.get_object_id(in_object_code), data.get_attribute_id(in_attribute_code), in_actor_id);
end;
$$
language plpgsql;

-- drop function data.get_attribute_value_for_share(integer, integer);

create or replace function data.get_attribute_value_for_share(in_object_id integer, in_attribute_id integer)
returns jsonb
volatile
as
$$
declare
  v_id integer;
  v_attribute_value jsonb;
  v_class_id integer;
begin
  assert data.is_instance(in_object_id);
  assert not data.can_attribute_be_overridden(in_attribute_id);

  select id, value
  into v_id, v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    value_object_id is null
  for share;

  if v_id is null then
    v_class_id := data.get_object_class_id(in_object_id);

    if v_class_id is not null then
      select value
      into v_attribute_value
      from data.attribute_values
      where
        object_id = v_class_id and
        attribute_id = in_attribute_id and
        value_object_id is null;
    end if;
  end if;

  if v_id is null then
    perform
    from data.objects
    where id = in_object_id
    for share;
  end if;

  return v_attribute_value;
end;
$$
language plpgsql;

-- drop function data.get_attribute_value_for_share(integer, text);

create or replace function data.get_attribute_value_for_share(in_object_id integer, in_attribute_code text)
returns jsonb
volatile
as
$$
begin
  return data.get_attribute_value_for_share(in_object_id, data.get_attribute_id(in_attribute_code));
end;
$$
language plpgsql;

-- drop function data.get_attribute_value_for_share(text, integer);

create or replace function data.get_attribute_value_for_share(in_object_code text, in_attribute_id integer)
returns jsonb
volatile
as
$$
begin
  return data.get_attribute_value_for_share(data.get_object_id(in_object_code), in_attribute_id);
end;
$$
language plpgsql;

-- drop function data.get_attribute_value_for_share(text, text);

create or replace function data.get_attribute_value_for_share(in_object_code text, in_attribute_code text)
returns jsonb
volatile
as
$$
begin
  return data.get_attribute_value_for_share(data.get_object_id(in_object_code), data.get_attribute_id(in_attribute_code));
end;
$$
language plpgsql;

-- drop function data.get_attribute_value_for_update(integer, integer);

create or replace function data.get_attribute_value_for_update(in_object_id integer, in_attribute_id integer)
returns jsonb
volatile
as
$$
declare
  v_id integer;
  v_attribute_value jsonb;
  v_class_id integer;
begin
  assert data.is_instance(in_object_id);
  assert not data.can_attribute_be_overridden(in_attribute_id);

  select id, value
  into v_id, v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    value_object_id is null
  for update;

  if v_id is null then
    v_class_id := data.get_object_class_id(in_object_id);

    if v_class_id is not null then
      select value
      into v_attribute_value
      from data.attribute_values
      where
        object_id = v_class_id and
        attribute_id = in_attribute_id and
        value_object_id is null;
    end if;
  end if;

  if v_id is null then
    perform
    from data.objects
    where id = in_object_id
    for update;
  end if;

  return v_attribute_value;
end;
$$
language plpgsql;

-- drop function data.get_attribute_value_for_update(integer, text);

create or replace function data.get_attribute_value_for_update(in_object_id integer, in_attribute_code text)
returns jsonb
volatile
as
$$
begin
  return data.get_attribute_value_for_update(in_object_id, data.get_attribute_id(in_attribute_code));
end;
$$
language plpgsql;

-- drop function data.get_attribute_value_for_update(text, integer);

create or replace function data.get_attribute_value_for_update(in_object_code text, in_attribute_id integer)
returns jsonb
volatile
as
$$
begin
  return data.get_attribute_value_for_update(data.get_object_id(in_object_code), in_attribute_id);
end;
$$
language plpgsql;

-- drop function data.get_attribute_value_for_update(text, text);

create or replace function data.get_attribute_value_for_update(in_object_code text, in_attribute_code text)
returns jsonb
volatile
as
$$
begin
  return data.get_attribute_value_for_update(data.get_object_id(in_object_code), data.get_attribute_id(in_attribute_code));
end;
$$
language plpgsql;

-- drop function data.get_bigint_param(text);

create or replace function data.get_bigint_param(in_code text)
returns bigint
stable
as
$$
begin
  assert in_code is not null;

  return
    json.get_bigint(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not a bigint', in_code;
end;
$$
language plpgsql;

-- drop function data.get_boolean_param(text);

create or replace function data.get_boolean_param(in_code text)
returns boolean
stable
as
$$
begin
  assert in_code is not null;

  return
    json.get_boolean(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not a boolean', in_code;
end;
$$
language plpgsql;

-- drop function data.get_class_id(text);

create or replace function data.get_class_id(in_class_code text)
returns integer
stable
as
$$
declare
  v_class_id integer;
begin
  assert in_class_code is not null;

  select id
  into v_class_id
  from data.objects
  where
    code = in_class_code and
    type = 'class';

  if v_class_id is null then
    raise exception 'Can''t find class "%"', in_class_code;
  end if;

  return v_class_id;
end;
$$
language plpgsql;

-- drop function data.get_integer_array_param(text);

create or replace function data.get_integer_array_param(in_code text)
returns integer[]
stable
as
$$
begin
  assert in_code is not null;

  return
    json.get_integer_array(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not an integer array', in_code;
end;
$$
language plpgsql;

-- drop function data.get_integer_param(text);

create or replace function data.get_integer_param(in_code text)
returns integer
stable
as
$$
begin
  assert in_code is not null;

  return
    json.get_integer(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not an integer', in_code;
end;
$$
language plpgsql;

-- drop function data.get_next_list(integer, integer);

create or replace function data.get_next_list(in_client_id integer, in_object_id integer)
returns jsonb
volatile
as
$$
declare
  v_page_size integer;
  v_object_code text;
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_last_object_id integer;
  v_content_value jsonb;
  v_content text[];
  v_client_subscription_id integer;
  v_object record;
  v_mini_card_function text;
  v_is_visible boolean;
  v_count integer := 0;
  v_has_more boolean := false;
  v_objects jsonb[] := array[]::jsonb[];
begin
  assert v_actor_id is not null;

  v_content_value := data.get_attribute_value(in_object_id, 'content', v_actor_id);
  if v_content_value is null then
    return null;
  end if;

  v_page_size := data.get_integer_param('page_size');
  assert v_page_size > 0;

  v_object_code := data.get_object_code(in_object_id);

  v_content = json.get_string_array(v_content_value);
  assert array_utils.is_unique(v_content);
  assert array_position(v_content, v_object_code) is null;

  select id
  into v_client_subscription_id
  from data.client_subscriptions
  where
    client_id = in_client_id and
    object_id = in_object_id;

  if v_client_subscription_id is null then
    raise exception 'Client % has no subscription for object %', client_id, object_id;
  end if;

  for v_object in
    select
      o.id id,
      c.num as index
    from (
      select
        row_number() over() as num,
        value
      from unnest(v_content) s(value)) c
    join data.objects o
      on o.code = c.value
    where
      o.id not in (
        select object_id
        from data.client_subscription_objects
        where client_subscription_id = v_client_subscription_id)
    order by c.num
  loop
    if v_count = v_page_size then
      v_has_more := true;
      exit;
    end if;

    -- Вызываем функцию на получение миникарточки объекта, если есть
    v_mini_card_function := json.get_string_opt(data.get_attribute_value(v_object.id, 'mini_card_function'), null);

    if v_mini_card_function is not null then
      execute format('select %s($1, $2)', v_mini_card_function)
      using v_object.id, v_actor_id;
    end if;

    -- Проверяем видимость
    v_is_visible := json.get_boolean_opt(data.get_attribute_value(v_object.id, 'is_visible', v_actor_id), false);

    insert into data.client_subscription_objects(client_subscription_id, object_id, index, is_visible)
    values(v_client_subscription_id, v_object.id, v_object.index, v_is_visible);

    if not v_is_visible then
      continue;
    end if;

    v_objects := array_append(v_objects, data.get_object(v_object.id, v_actor_id, 'mini', in_object_id));

    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('objects', to_jsonb(v_objects), 'has_more', v_has_more);
end;
$$
language plpgsql;

-- drop function data.get_object(integer, integer, data.card_type, integer);

create or replace function data.get_object(in_object_id integer, in_actor_id integer, in_card_type data.card_type, in_actions_object_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_data jsonb := data.get_object_data(in_object_id, in_actor_id, in_card_type, in_actions_object_id);
  v_attributes jsonb := json.get_object(v_object_data, 'attributes');
  v_actions jsonb := json.get_object_opt(v_object_data, 'actions', null);
  v_template jsonb :=
    json.get_object_opt(
      (
        case when in_card_type = 'full' then
          data.get_attribute_value(in_object_id, 'template')
        else
          coalesce(
            data.get_attribute_value(in_object_id, 'mini_card_template'),
            data.get_attribute_value(in_object_id, 'template'))
        end
      ),
      null);
begin
  if v_template is null then
    v_template := data.get_param('template');
  end if;

  -- Отфильтровываем из шаблона лишнее
  v_template := data.filter_template(v_template, v_attributes, v_actions);

  return jsonb_build_object('id', data.get_object_code(in_object_id), 'attributes', v_attributes, 'actions', coalesce(v_actions, jsonb '{}'), 'template', v_template);
end;
$$
language plpgsql;

-- drop function data.get_object_class_id(integer);

create or replace function data.get_object_class_id(in_object_id integer)
returns integer
stable
as
$$
declare
  v_class_id integer;
begin
  assert data.is_instance(in_object_id);

  select class_id
  into v_class_id
  from data.objects
  where id = in_object_id;

  return v_class_id;
end;
$$
language plpgsql;

-- drop function data.get_object_code(integer);

create or replace function data.get_object_code(in_object_id integer)
returns text
stable
as
$$
declare
  v_object_code text;
begin
  assert in_object_id is not null;

  select code
  into v_object_code
  from data.objects
  where
    id = in_object_id and
    type = 'instance';

  if v_object_code is null then
    raise exception 'Can''t find object %', in_object_id;
  end if;

  return v_object_code;
end;
$$
language plpgsql;

-- drop function data.get_object_data(integer, integer, data.card_type, integer);

create or replace function data.get_object_data(in_object_id integer, in_actor_id integer, in_card_type data.card_type, in_actions_object_id integer)
returns jsonb
volatile
as
$$
declare
  v_priority_attribute_id integer := data.get_attribute_id('priority');
  v_attributes jsonb := jsonb '{}';
  v_attribute record;
  v_attribute_json jsonb;
  v_value_description text;
  v_actions_function_attribute text :=
    (case when in_object_id = in_actions_object_id then 'actions_function' else 'list_actions_function' end);
  v_actions_function text;
  v_actions jsonb;
begin
  assert data.is_instance(in_object_id);
  assert data.is_instance(in_actor_id);
  assert in_object_id = in_actions_object_id or data.is_instance(in_actions_object_id);
  assert in_card_type is not null;

  -- Получаем видимые и hidden-атрибуты для указанной карточки
  for v_attribute in
    select
      a.id,
      a.code,
      a.name,
      attr.value,
      a.value_description_function
    from (
      select
        av.attribute_id,
        av.value,
        case
          when
            lag(av.attribute_id) over(
              partition by av.attribute_id
              order by greatest(json.get_integer_opt(pr2.value, 0), json.get_integer_opt(pr.value, 0)) desc, data.is_instance(av.object_id) desc
            ) is null
          then true
          else false
        end as needed
      from data.attribute_values av
      left join data.object_objects oo on
        av.value_object_id = oo.parent_object_id and
        oo.object_id = in_actor_id
      left join data.attribute_values pr on
        pr.object_id = av.value_object_id and
        pr.attribute_id = v_priority_attribute_id and
        pr.value_object_id is null
      left join data.objects o on
        o.id = av.value_object_id and
        pr.id is null
      left join data.attribute_values pr2 on
        pr2.object_id = o.class_id and
        pr2.attribute_id = v_priority_attribute_id and
        pr2.value_object_id is null
      where
        (av.object_id = in_object_id or av.object_id = data.get_object_class_id(in_object_id)) and
        (av.value_object_id is null or oo.id is not null)
    ) attr
    join data.attributes a
      on a.id = attr.attribute_id
      and (a.card_type is null or a.card_type = in_card_type)
      and a.type != 'system'
    where attr.needed = true
    order by a.code
  loop
    v_attribute_json := jsonb '{}';
    if v_attribute.value_description_function is not null then
      execute format('select %s($1, $2, $3, $4)', v_attribute.value_description_function)
      using v_attribute.id, v_attribute.value, in_card_type, in_actor_id
      into v_value_description;

      if v_value_description is not null then
        v_attribute_json := v_attribute_json || jsonb_build_object('value_description', v_value_description);
      end if;
    end if;

    if v_attribute.name is not null then
      v_attribute_json := v_attribute_json || jsonb_build_object('name', v_attribute.name, 'value', v_attribute.value);
    else
      v_attribute_json := v_attribute_json || jsonb_build_object('value', v_attribute.value);
    end if;

    v_attributes := v_attributes || jsonb_build_object(v_attribute.code, v_attribute_json);
  end loop;

  -- Получаем действия объекта
  v_actions_function := json.get_string_opt(data.get_attribute_value(in_actions_object_id, v_actions_function_attribute), null);

  if v_actions_function is not null then
    if in_object_id = in_actions_object_id then
      execute format('select %s($1, $2)', v_actions_function)
      using in_object_id, in_actor_id
      into v_actions;
    else
      execute format('select %s($1, $2, $3)', v_actions_function)
      using in_actions_object_id, in_object_id, in_actor_id
      into v_actions;
    end if;
  end if;

  return jsonb_build_object('attributes', v_attributes, 'actions', v_actions);
end;
$$
language plpgsql;

-- drop function data.get_object_id(text);

create or replace function data.get_object_id(in_object_code text)
returns integer
stable
as
$$
declare
  v_object_id integer;
begin
  assert in_object_code is not null;

  select id
  into v_object_id
  from data.objects
  where
    code = in_object_code and
    type = 'instance';

  if v_object_id is null then
    raise exception 'Can''t find object "%"', in_object_code;
  end if;

  return v_object_id;
end;
$$
language plpgsql;

-- drop function data.get_object_id_opt(text);

create or replace function data.get_object_id_opt(in_object_code text)
returns integer
stable
as
$$
declare
  v_object_id integer;
begin
  if in_object_code is not null then 
    v_object_id :=  data.get_object_id(in_object_code);
  end if;
  return v_object_id;
end;
$$
language plpgsql;

-- drop function data.get_object_param(text);

create or replace function data.get_object_param(in_code text)
returns jsonb
stable
as
$$
begin
  assert in_code is not null;

  return
    json.get_object(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not an object', in_code;
end;
$$
language plpgsql;

-- drop function data.get_param(text);

create or replace function data.get_param(in_code text)
returns jsonb
stable
as
$$
declare
  v_value jsonb;
begin
  assert in_code is not null;

  select value
  into v_value
  from data.params
  where code = in_code;

  if v_value is null then
    raise exception 'Param "%" was not found', in_code;
  end if;

  return v_value;
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value(integer, integer);

create or replace function data.get_raw_attribute_value(in_object_id integer, in_attribute_id integer)
returns jsonb
stable
as
$$
declare
  v_attribute_value jsonb;
begin
  assert data.is_class_or_object_exists(in_object_id);
  perform data.get_attribute_code(in_attribute_id);

  select value
  into v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    value_object_id is null;

  return v_attribute_value;
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value(integer, integer, integer);

create or replace function data.get_raw_attribute_value(in_object_id integer, in_attribute_id integer, in_value_object_id integer)
returns jsonb
stable
as
$$
declare
  v_object_exists boolean;
  v_attribute_value jsonb;
begin
  if in_value_object_id is null then
    return data.get_raw_attribute_value(in_object_id, in_attribute_id);
  end if;

  assert data.is_class_or_object_exists(in_object_id);
  assert data.is_instance(in_value_object_id);
  assert data.can_attribute_be_overridden(in_attribute_id);

  select value
  into v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    value_object_id = in_value_object_id;

  return v_attribute_value;
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value(integer, integer, text);

create or replace function data.get_raw_attribute_value(in_object_id integer, in_attribute_id integer, in_value_object_code text)
returns jsonb
stable
as
$$
begin
  return data.get_raw_attribute_value(in_object_id, in_attribute_id, data.get_object_id(in_value_object_code));
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value(integer, text);

create or replace function data.get_raw_attribute_value(in_object_id integer, in_attribute_code text)
returns jsonb
stable
as
$$
begin
  return data.get_raw_attribute_value(in_object_id, data.get_attribute_id(in_attribute_code));
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value(integer, text, integer);

create or replace function data.get_raw_attribute_value(in_object_id integer, in_attribute_code text, in_value_object_id integer)
returns jsonb
stable
as
$$
begin
  return data.get_raw_attribute_value(in_object_id, data.get_attribute_id(in_attribute_code), in_value_object_id);
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value(integer, text, text);

create or replace function data.get_raw_attribute_value(in_object_id integer, in_attribute_code text, in_value_object_code text)
returns jsonb
stable
as
$$
begin
  return data.get_raw_attribute_value(in_object_id, data.get_attribute_id(in_attribute_code), data.get_object_id(in_value_object_code));
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value(text, integer);

create or replace function data.get_raw_attribute_value(in_object_code text, in_attribute_id integer)
returns jsonb
stable
as
$$
begin
  return data.get_raw_attribute_value(data.get_object_id(in_object_code), in_attribute_id);
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value(text, integer, integer);

create or replace function data.get_raw_attribute_value(in_object_code text, in_attribute_id integer, in_value_object_id integer)
returns jsonb
stable
as
$$
begin
  return data.get_raw_attribute_value(data.get_object_id(in_object_code), in_attribute_id, in_value_object_id);
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value(text, integer, text);

create or replace function data.get_raw_attribute_value(in_object_code text, in_attribute_id integer, in_value_object_code text)
returns jsonb
stable
as
$$
begin
  return data.get_raw_attribute_value(data.get_object_id(in_object_code), in_attribute_id, data.get_object_id(in_value_object_code));
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value(text, text);

create or replace function data.get_raw_attribute_value(in_object_code text, in_attribute_code text)
returns jsonb
stable
as
$$
begin
  return data.get_raw_attribute_value(data.get_object_id(in_object_code), data.get_attribute_id(in_attribute_code));
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value(text, text, integer);

create or replace function data.get_raw_attribute_value(in_object_code text, in_attribute_code text, in_value_object_id integer)
returns jsonb
stable
as
$$
begin
  return data.get_raw_attribute_value(data.get_object_id(in_object_code), data.get_attribute_id(in_attribute_code), in_value_object_id);
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value(text, text, text);

create or replace function data.get_raw_attribute_value(in_object_code text, in_attribute_code text, in_value_object_code text)
returns jsonb
stable
as
$$
begin
  return data.get_raw_attribute_value(data.get_object_id(in_object_code), data.get_attribute_id(in_attribute_code), data.get_object_id(in_value_object_code));
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value_for_share(integer, integer);

create or replace function data.get_raw_attribute_value_for_share(in_object_id integer, in_attribute_id integer)
returns jsonb
volatile
as
$$
declare
  v_id integer;
  v_attribute_value jsonb;
begin
  -- Блокировать класс неправильно, слишком большая видимость
  assert data.is_instance(in_object_id);
  perform data.get_attribute_code(in_attribute_id);

  select id, value
  into v_id, v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    value_object_id is null
  for share;

  if v_id is null then
    perform
    from data.objects
    where id = in_object_id
    for share;
  end if;

  return v_attribute_value;
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value_for_share(integer, integer, integer);

create or replace function data.get_raw_attribute_value_for_share(in_object_id integer, in_attribute_id integer, in_value_object_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_exists boolean;
  v_id integer;
  v_attribute_value jsonb;
begin
  if in_value_object_id is null then
    return data.get_raw_attribute_value_for_share(in_object_id, in_attribute_id);
  end if;

  -- Блокировать класс неправильно, слишком большая видимость
  assert data.is_instance(in_object_id);
  assert data.is_instance(in_value_object_id);
  assert data.can_attribute_be_overridden(in_attribute_id);

  select id, value
  into v_id, v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    value_object_id = in_value_object_id
  for share;

  if v_id is null then
    perform
    from data.objects
    where id = in_object_id
    for share;
  end if;

  return v_attribute_value;
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value_for_share(integer, text);

create or replace function data.get_raw_attribute_value_for_share(in_object_id integer, in_attribute_code text)
returns jsonb
volatile
as
$$
begin
  return data.get_raw_attribute_value_for_share(in_object_id, data.get_attribute_id(in_attribute_code));
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value_for_share(integer, text, integer);

create or replace function data.get_raw_attribute_value_for_share(in_object_id integer, in_attribute_code text, in_value_object_id integer)
returns jsonb
volatile
as
$$
begin
  return data.get_raw_attribute_value_for_share(in_object_id, data.get_attribute_id(in_attribute_code), in_value_object_id);
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value_for_update(integer, integer);

create or replace function data.get_raw_attribute_value_for_update(in_object_id integer, in_attribute_id integer)
returns jsonb
volatile
as
$$
declare
  v_id integer;
  v_attribute_value jsonb;
begin
  -- Блокировать класс неправильно, слишком большая видимость
  assert data.is_instance(in_object_id);
  perform data.get_attribute_code(in_attribute_id);

  select id, value
  into v_id, v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    value_object_id is null
  for update;

  if v_id is null then
    perform
    from data.objects
    where id = in_object_id
    for update;
  end if;

  return v_attribute_value;
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value_for_update(integer, integer, integer);

create or replace function data.get_raw_attribute_value_for_update(in_object_id integer, in_attribute_id integer, in_value_object_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_exists boolean;
  v_id integer;
  v_attribute_value jsonb;
begin
  if in_value_object_id is null then
    return data.get_raw_attribute_value_for_update(in_object_id, in_attribute_id);
  end if;

  -- Блокировать класс неправильно, слишком большая видимость
  assert data.is_instance(in_object_id);
  assert data.is_instance(in_value_object_id);
  assert data.can_attribute_be_overridden(in_attribute_id);

  select id, value
  into v_id, v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    value_object_id = in_value_object_id
  for update;

  if v_id is null then
    perform
    from data.objects
    where id = in_object_id
    for update;
  end if;

  return v_attribute_value;
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value_for_update(integer, text);

create or replace function data.get_raw_attribute_value_for_update(in_object_id integer, in_attribute_code text)
returns jsonb
volatile
as
$$
begin
  return data.get_raw_attribute_value_for_update(in_object_id, data.get_attribute_id(in_attribute_code));
end;
$$
language plpgsql;

-- drop function data.get_raw_attribute_value_for_update(integer, text, integer);

create or replace function data.get_raw_attribute_value_for_update(in_object_id integer, in_attribute_code text, in_value_object_id integer)
returns jsonb
volatile
as
$$
begin
  return data.get_raw_attribute_value_for_update(in_object_id, data.get_attribute_id(in_attribute_code), in_value_object_id);
end;
$$
language plpgsql;

-- drop function data.get_string_param(text);

create or replace function data.get_string_param(in_code text)
returns text
stable
as
$$
begin
  assert in_code is not null;

  return
    json.get_string(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not a string', in_code;
end;
$$
language plpgsql;

-- drop function data.init();

create or replace function data.init()
returns void
volatile
as
$$
begin
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  (
    'actions_function',
    null,
    'Функция, вызываемая перед получением действий объекта, string. Вызывается с параметрами (object_id, actor_id) и возвращает действия.
Функция не может изменять объекты базы данных, т.е. должна быть stable или immutable.',
    'system',
    null,
    null,
    false
  ),
  (
    'actor_function',
    null,
    'Функция, вызываемая перед получением заголовка и подзаголовка актора, string. Вызывается с параметром (object_id).',
    'system',
    null,
    null,
    false
  ),
  ('content', null, 'Массив кодов объектов списка, text[]', 'system', null, null, true),
  (
    'full_card_function',
    null,
    'Функция, вызываемая перед получением полной карточки объекта, string. Вызывается с параметрами  (object_id, actor_id).',
    'system',
    null,
    null,
    false
  ),
  ('is_visible', null, 'Определяет, доступен ли объект текущему актору, boolean', 'system', null, null, true),
  (
    'list_actions_function',
    null,
    'Функция, вызываемая перед получением действий объекта списка, string. Вызывается с параметрами (object_id, list_object_id, actor_id) и возвращает действия.
Функция не может изменять объекты базы данных, т.е. должна быть stable или immutable.',
    'system',
    null,
    null,
    false
  ),
  (
    'list_element_function',
    null,
    'Функция, вызываемая при открытии какого-то объекта из данного объекта-списка, string. Вызывается с параметрами (client_id, request_id, object_id, list_object_id). Функция должна либо бросить исключение, либо сгенерировать сообщение клиенту.
Если атрибут отсутствует, то сообщение open_list_object всегда приводит к действию open_object.',
    'system',
    null,
    null,
    false
  ),
  (
    'mini_card_function',
    null,
    'Функция, вызываемая перед получением миникарточки объекта, string. Вызывается с параметрами (object_id, actor_id).',
    'system',
    null,
    null,
    false
  ),
  ('mini_card_template', null, 'Шаблон миникарточки объекта, object', 'system', null, null, false),
  (
    'priority',
    null,
    'Приоритет группы, integer. Для стабильной работы приоритет всех групп (объектов, включающих другие объекты) должен быть уникальным. Значение приоритета по умолчанию - 0.',
    'system',
    null,
    null,
    false
  ),
  ('redirect', null, 'Содержит идентификатор объекта, который должен быть возвращён вместо запрошенного при получении полной карточки объекта, integer.', 'system', null, null, true),
  ('subtitle', null, 'Подзаголовок, string', 'normal', null, null, false),
  ('template', null, 'Шаблон объекта, object', 'system', null, null, false),
  ('temporary_object', null, 'Атрибут, наличие которого говорит о том, что открытый объект не нужно сохранять в истории', 'hidden', 'full', null, false),
  ('title', null, 'Заголовок, string', 'normal', null, null, false),
  (
    'touch_function',
    null,
    'Функция, вызываемая при смахивании уведомления, string. Вызывается с параметрами (object_id, actor_id).
Если атрибут отсутствует, то сообщение touch просто игнорируется.',
    'system',
    null,
    null,
    false
  ),
  ('type', null, 'Тип объекта, string', 'hidden', null, null, false);

  insert into data.params(code, value, description) values
  ('page_size', jsonb '10', 'Количество элементов списка, получаемых за один раз'),
  ('template', jsonb '{"groups": []}', 'Шаблон по умолчанию');
end;
$$
language plpgsql;

-- drop function data.is_class_or_object_exists(integer);

create or replace function data.is_class_or_object_exists(in_object_id integer)
returns boolean
stable
as
$$
declare
  v_exists boolean;
begin
  assert in_object_id is not null;

  select true
  into v_exists
  from data.objects
  where id = in_object_id;

  return coalesce(v_exists, false);
end;
$$
language plpgsql;

-- drop function data.is_class_or_object_exists(text);

create or replace function data.is_class_or_object_exists(in_object_code text)
returns boolean
stable
as
$$
declare
  v_exists boolean;
begin
  assert in_object_code is not null;

  select true
  into v_exists
  from data.objects
  where code = in_object_code;

  return coalesce(v_exists, false);
end;
$$
language plpgsql;

-- drop function data.is_hidden_attribute(integer);

create or replace function data.is_hidden_attribute(in_attribute_id integer)
returns boolean
stable
as
$$
declare
  v_ret_val boolean;
begin
  select type = 'hidden'
  into v_ret_val
  from data.attributes
  where id = in_attribute_id;

  if v_ret_val is null then
    raise exception 'Attribute % was not found', in_attribute_id;
  end if;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function data.is_instance(integer);

create or replace function data.is_instance(in_object_id integer)
returns boolean
stable
as
$$
declare
  v_type data.object_type;
begin
  assert in_object_id is not null;

  select type
  into v_type
  from data.objects
  where id = in_object_id;

  assert v_type is not null;

  return v_type = 'instance';
end;
$$
language plpgsql;

-- drop function data.is_object_exists(integer);

create or replace function data.is_object_exists(in_object_id integer)
returns boolean
stable
as
$$
declare
  v_exists boolean;
begin
  assert in_object_id is not null;

  select true
  into v_exists
  from data.objects
  where
    id = in_object_id and
    type = 'instance';

  return coalesce(v_exists, false);
end;
$$
language plpgsql;

-- drop function data.is_object_exists(text);

create or replace function data.is_object_exists(in_object_code text)
returns boolean
stable
as
$$
declare
  v_exists boolean;
begin
  assert in_object_code is not null;

  select true
  into v_exists
  from data.objects
  where
    code = in_object_code and
    type = 'instance';

  return coalesce(v_exists, false);
end;
$$
language plpgsql;

-- drop function data.is_system_attribute(integer);

create or replace function data.is_system_attribute(in_attribute_id integer)
returns boolean
stable
as
$$
declare
  v_ret_val boolean;
begin
  select type = 'system'
  into v_ret_val
  from data.attributes
  where id = in_attribute_id;

  if v_ret_val is null then
    raise exception 'Attribute % was not found', in_attribute_id;
  end if;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function data.log(data.severity, text, integer);

create or replace function data.log(in_severity data.severity, in_message text, in_actor_id integer default null::integer)
returns void
volatile
as
$$
begin
  assert in_actor_id is null or data.is_instance(in_actor_id);

  insert into data.log(severity, message, actor_id)
  values(in_severity, coalesce(in_message, '<null>'), in_actor_id);

  if in_severity = 'error' then
    perform data.metric_add('error_count', 1);
  end if;
end;
$$
language plpgsql;

-- drop function data.metric_add(data.metric_type, integer);

create or replace function data.metric_add(in_type data.metric_type, in_value integer)
returns void
volatile
as
$$
declare
  v_new_value integer;
begin
  assert in_type is not null;
  assert in_value is not null;

  insert into data.metrics as m (type, value)
  values (in_type, in_value)
  on conflict (type) do update
  set value = m.value + in_value
  returning value into v_new_value;

  perform api_utils.create_metric_notification(in_type, v_new_value);
end;
$$
language plpgsql;

-- drop function data.metric_set_max(data.metric_type, integer);

create or replace function data.metric_set_max(in_type data.metric_type, in_value integer)
returns void
volatile
as
$$
declare
  v_id integer;
begin
  assert in_type is not null;
  assert in_value is not null;

  insert into data.metrics as m (type, value)
  values (in_type, in_value)
  on conflict (type) do update
  set value = in_value
  where m.value < in_value
  returning id into v_id;

  if v_id is not null then
    perform api_utils.create_metric_notification(in_type, in_value);
  end if;
end;
$$
language plpgsql;

-- drop function data.objects_after_insert();

create or replace function data.objects_after_insert()
returns trigger
volatile
as
$$
begin
  if new.type = 'instance' then
    insert into data.object_objects(parent_object_id, object_id)
    values(new.id, new.id);
  end if;

  return null;
end;
$$
language plpgsql;

-- drop function data.preprocess_changes_with_codes(jsonb);

create or replace function data.preprocess_changes_with_codes(in_changes jsonb)
returns jsonb
stable
as
$$
-- У параметра in_changes есть два возможных формата:
-- 1. Только для установки значения: объект, где ключ - код атрибута, а значение - значение атрибута
-- 2. Массив объектов с полями id или code, value_object_id, или value_object_code, value

-- Возвращается массив объектов с полями id, value_object_id, value
declare
  v_change record;
  v_elem jsonb;
  v_ret_val jsonb := '[]';
begin
  assert in_changes is not null;

  if jsonb_typeof(in_changes) = 'object' then
    for v_change in
    (
      select key, value
      from jsonb_each(in_changes)
    )
    loop
      v_ret_val := v_ret_val || jsonb_build_object('id', data.get_attribute_id(v_change.key), 'value', v_change.value);
    end loop;
  else
    for v_change in
    (
      select
        json.get_integer_opt(value, 'id', null) id,
        json.get_string_opt(value, 'code', null) code,
        json.get_integer_opt(value, 'value_object_id', null) value_object_id,
        json.get_string_opt(value, 'value_object_code', null) value_object_code,
        value->'value' as value
      from jsonb_array_elements(in_changes)
    )
    loop
      v_elem := '{}';

      if v_change.id is not null then
        assert v_change.code is null;

        v_elem := v_elem || jsonb_build_object('id', v_change.id);
      else
        assert v_change.code is not null;

        v_elem := v_elem || jsonb_build_object('id', data.get_attribute_id(v_change.code));
      end if;

      if v_change.value_object_id is not null then
        assert v_change.value_object_code is null;

        v_elem := v_elem || jsonb_build_object('value_object_id', v_change.value_object_id);
      elsif v_change.value_object_code is not null then
        v_elem := v_elem || jsonb_build_object('value_object_id', data.get_object_id(v_change.value_object_code));
      end if;

      if v_change.value is not null then
        v_elem := v_elem || jsonb_build_object('value', v_change.value);
      end if;

      v_ret_val := v_ret_val || v_elem;
    end loop;
  end if;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function data.process_diffs_and_notify(jsonb);

create or replace function data.process_diffs_and_notify(in_diffs jsonb)
returns void
volatile
as
$$
declare
  v_diff record;
  v_notification_data jsonb;
begin
  assert json.is_object_array(in_diffs);

  for v_diff in
  (
    select
      json.get_string(value, 'object_id') as object_id,
      json.get_integer(value, 'client_id') as client_id,
      (case when value ? 'object' then value->'object' else null end) as object,
      (case when value ? 'list_changes' then value->'list_changes' else null end) as list_changes
    from jsonb_array_elements(in_diffs)
  )
  loop
    v_notification_data := jsonb_build_object('object_id', v_diff.object_id);

    if v_diff.object is not null then
      v_notification_data := v_notification_data || jsonb_build_object('object', v_diff.object);
    end if;

    if v_diff.list_changes is not null then
      v_notification_data := v_notification_data || jsonb_build_object('list_changes', v_diff.list_changes);
    end if;

    perform api_utils.create_notification(v_diff.client_id, null, 'diff', v_notification_data);
  end loop;
end;
$$
language plpgsql;

-- drop function data.process_diffs_and_notify_current_object(jsonb, integer, text, integer);

create or replace function data.process_diffs_and_notify_current_object(in_diffs jsonb, in_client_id integer, in_request_id text, in_object_id integer)
returns boolean
volatile
as
$$
declare
  v_subscription_exists boolean;
  v_diff record;
  v_object_code text := data.get_object_code(in_object_id);
  v_message_sent boolean := false;
  v_request_id text;
  v_notification_data jsonb;
begin
  assert json.is_object_array(in_diffs);
  assert in_client_id is not null;
  assert in_request_id is not null;

  select true
  into v_subscription_exists
  from data.client_subscriptions
  where
    client_id = in_client_id and
    object_id = in_object_id;

  -- Если стреляет этот ассерт, то нам нужно вызывать другую функцию
  assert v_subscription_exists;

  for v_diff in
  (
    select
      json.get_string(value, 'object_id') as object_id,
      json.get_integer(value, 'client_id') as client_id,
      (case when value ? 'object' then value->'object' else null end) as object,
      (case when value ? 'list_changes' then value->'list_changes' else null end) as list_changes
    from jsonb_array_elements(in_diffs)
  )
  loop
    assert v_diff.object is not null or v_diff.list_changes is not null;

    if v_diff.client_id = in_client_id and v_diff.object_id = v_object_code then
      assert not v_message_sent;

      v_message_sent := true;

      v_request_id := in_request_id;
    else
      v_request_id := null;
    end if;

    v_notification_data := jsonb_build_object('object_id', v_diff.object_id);

    if v_diff.object is not null then
      v_notification_data := v_notification_data || jsonb_build_object('object', v_diff.object);
    end if;

    if v_diff.list_changes is not null then
      v_notification_data := v_notification_data || jsonb_build_object('list_changes', v_diff.list_changes);
    end if;

    perform api_utils.create_notification(v_diff.client_id, v_request_id, 'diff', v_notification_data);
  end loop;

  return v_message_sent;
end;
$$
language plpgsql;

-- drop function data.remove_object_from_object(integer, integer, integer, text);

create or replace function data.remove_object_from_object(in_object_id integer, in_parent_object_id integer, in_actor_id integer default null::integer, in_reason text default null::text)
returns void
volatile
as
$$
-- Как правило вместо этой функции следует вызывать data.change_object_groups
declare
  v_connection_id integer;
  v_ids integer[];
begin
  assert data.is_instance(in_object_id);
  assert data.is_instance(in_parent_object_id);
  assert in_actor_id is null or data.is_instance(in_actor_id);

  if in_object_id = in_parent_object_id then
    raise exception 'Attempt to remove object % from itself', in_object_id;
  end if;

  -- Блокируем запись, чтобы параллельно с нами никто не удалил из той же группы
  select id
  into v_connection_id
  from data.object_objects
  where
    parent_object_id = in_parent_object_id and
    object_id = in_object_id and
    intermediate_object_ids is null
  for update;

  if v_connection_id is null then
    raise exception 'Attempt to remove non-existing connection from object % to object %', in_object_id, in_parent_object_id;
  end if;

  -- Блокируем parent'ы и child'ы на чтение, чтобы никто за это время не поменял нужные нам группы
  perform *
  from data.object_objects
  where
    id in (
      select oo.id
      from (
        select array_agg(os.value) as value
        from
        (
          select distinct(object_id) as value
          from data.object_objects
          where parent_object_id = in_object_id
        ) os
      ) o
      join (
        select array_agg(ps.value) as value
        from
        (
          select distinct(parent_object_id) as value
          from data.object_objects
          where object_id = in_parent_object_id
        ) ps
      ) po
      on true
      join data.object_objects oo
      on
        (
          (
            oo.parent_object_id = any(o.value) and
            oo.object_id = any(o.value)
          ) or
          (
            oo.parent_object_id = any(po.value) and
            oo.object_id = any(po.value)
          )
        ) and
        oo.intermediate_object_ids is null
    )
  for share;

  select array_agg(i.id)
  into v_ids
  from (
    select oo.id
    from (
      select array_agg(os.value) as value
      from
      (
        select distinct(object_id) as value
        from data.object_objects
        where parent_object_id = in_object_id
      ) os
    ) o
    join (
      select array_agg(ps.value) as value
      from
      (
        select distinct(parent_object_id) as value
        from data.object_objects
        where object_id = in_parent_object_id
      ) ps
    ) po
    on true
    join data.object_objects oo
    on
      parent_object_id = any(po.value) and
      object_id = any(o.value) and
      array_position(intermediate_object_ids, in_object_id) = array_position(intermediate_object_ids, in_parent_object_id) - 1
    union
    select id
    from data.object_objects
    where
      object_id = in_object_id and
      intermediate_object_ids[1] = in_parent_object_id
    union
    select id
    from data.object_objects
    where
      parent_object_id = in_parent_object_id and
      intermediate_object_ids[array_length(intermediate_object_ids, 1)] = in_object_id
    union
    select v_connection_id
  ) i;

  insert into data.object_objects_journal(parent_object_id, object_id, intermediate_object_ids, start_time, start_reason, start_actor_id, end_time, end_reason, end_actor_id)
  select parent_object_id, object_id, intermediate_object_ids, start_time, start_reason, start_actor_id, clock_timestamp(), in_reason, in_actor_id
  from data.object_objects
  where id = any(v_ids);

  delete from data.object_objects
  where id = any(v_ids);
end;
$$
language plpgsql;

-- drop function data.set_attribute_value(integer, integer, jsonb, integer, integer, text);

create or replace function data.set_attribute_value(in_object_id integer, in_attribute_id integer, in_value jsonb, in_value_object_id integer default null::integer, in_actor_id integer default null::integer, in_reason text default null::text)
returns void
volatile
as
$$
-- Как правило вместо этой функции следует вызывать data.change_object
-- Эта функция не проставляет правильно блокировки и не рассылает уведомлений
declare
  v_attribute_value record;
  v_end_time timestamp with time zone;
begin
  assert data.is_instance(in_object_id);
  assert in_attribute_id is not null;
  assert in_value is not null;
  assert in_actor_id is null or data.is_instance(in_actor_id);

  if in_value_object_id is null then
    select id, object_id, attribute_id, value_object_id, value, start_time, start_reason, start_actor_id
    into v_attribute_value
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id is null;
  else
    select id, object_id, attribute_id, value_object_id, value, start_time, start_reason, start_actor_id
    into v_attribute_value
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id = in_value_object_id;
  end if;

  if v_attribute_value is null then
    insert into data.attribute_values(object_id, attribute_id, value_object_id, value, start_reason, start_actor_id)
    values(in_object_id, in_attribute_id, in_value_object_id, in_value, in_reason, in_actor_id);
  else
    assert (in_value is null) != (v_attribute_value.value is null) or in_value is not null and in_value != v_attribute_value.value;

    insert into data.attribute_values_journal(
      object_id,
      attribute_id,
      value_object_id,
      value,
      start_time,
      start_reason,
      start_actor_id,
      end_time,
      end_reason,
      end_actor_id)
    values(
      in_object_id,
      in_attribute_id,
      in_value_object_id,
      v_attribute_value.value,
      v_attribute_value.start_time,
      v_attribute_value.start_reason,
      v_attribute_value.start_actor_id,
      clock_timestamp(),
      in_reason,
      in_actor_id)
    returning end_time into v_end_time;

    update data.attribute_values
    set
      value = in_value,
      start_time = v_end_time,
      start_reason = in_reason,
      start_actor_id = in_actor_id
    where id = v_attribute_value.id;
  end if;
end;
$$
language plpgsql;

-- drop function data.set_attribute_value(integer, text, jsonb, integer, integer, text);

create or replace function data.set_attribute_value(in_object_id integer, in_attribute_code text, in_value jsonb, in_value_object_id integer default null::integer, in_actor_id integer default null::integer, in_reason text default null::text)
returns void
volatile
as
$$
-- Как правило вместо этой функции следует вызывать data.change_object
-- Эта функция не проставляет правильно блокировки и не рассылает уведомлений
begin
  perform data.set_attribute_value(in_object_id, data.get_attribute_id(in_attribute_code), in_value, in_value_object_id, in_actor_id, in_reason);
end;
$$
language plpgsql;

-- drop function data.set_login(integer, integer);

create or replace function data.set_login(in_client_id integer, in_login_id integer)
returns void
volatile
as
$$
declare
  v_is_connected boolean;
begin
  update data.clients
  set
    login_id = in_login_id,
    actor_id = null
  where id = in_client_id
  returning is_connected
  into v_is_connected;

  assert v_is_connected is not null;

  if v_is_connected then
    delete from data.client_subscription_objects
    where client_subscription_id in (
      select id
      from data.client_subscriptions
      where client_id = in_client_id);

    delete from data.client_subscriptions
    where client_id = in_client_id;
  end if;
end;
$$
language plpgsql;

-- drop function data_internal.process_saved_state(jsonb);

create or replace function data_internal.process_saved_state(in_state jsonb)
returns jsonb
volatile
as
$$
declare
  v_ret_val jsonb := jsonb '[]';

  v_set_visible integer[];
  v_set_invisible integer[];

  v_content_attr_id integer;
  v_subscription record;
  v_full_card_function text;
  v_subscription_object_code text;
  v_new_data jsonb;
  v_object jsonb;
  v_new_content jsonb;
  v_remove_list_changes jsonb;
  v_add_list_changes jsonb;
  v_change_list_changes jsonb;
  v_list_changes jsonb;
  v_ret_val_element jsonb;
begin
  assert json.is_object_array(in_state);

  if in_state = jsonb '[]' then
    return v_ret_val;
  end if;

  v_content_attr_id := data.get_attribute_id('content');

  for v_subscription in
  (
    select
      json.get_integer(value, 'id') as id,
      json.get_integer(value, 'client_id') as client_id,
      json.get_integer(value, 'object_id') as object_id,
      json.get_integer(value, 'actor_id') as actor_id,
      json.get_object(value, 'data') as data,
      json.get_array_opt(value, 'content', null) as content,
      json.get_array(value, 'list_objects') as list_objects
    from jsonb_array_elements(in_state)
  )
  loop
    v_full_card_function :=
      json.get_string_opt(
        data.get_attribute_value(v_subscription.object_id, 'full_card_function'),
        null);

    if v_full_card_function is not null then
      execute format('select %s($1, $2)', v_full_card_function)
      using v_subscription.object_id, v_subscription.actor_id;
    end if;

    v_subscription_object_code := data.get_object_code(v_subscription.object_id);

    -- Объект стал невидимым - отправляем специальный diff и вычищаем подписки
    if not json.get_boolean_opt(data.get_attribute_value(v_subscription.object_id, 'is_visible', v_subscription.actor_id), false) then
      v_ret_val :=
        v_ret_val ||
        jsonb_build_object(
          'object_id',
          v_subscription_object_code,
          'client_id',
          v_subscription.client_id,
          'object',
          jsonb 'null');

      delete from data.client_subscription_objects
      where client_subscription_id = v_subscription.id;

      delete from data.client_subscriptions
      where id = v_subscription.id;

      continue;
    end if;

    v_new_data := data.get_object(v_subscription.object_id, v_subscription.actor_id, 'full', v_subscription.object_id);

    v_object := null;
    v_list_changes := jsonb '{}';
    v_remove_list_changes := jsonb '[]';
    v_add_list_changes := jsonb '[]';
    v_change_list_changes := jsonb '[]';

    -- Сравниваем и при нахождении различий включаем в diff
    if v_new_data != v_subscription.data then
      v_object := v_new_data;
    end if;

    v_new_content := data.get_attribute_value(v_subscription.object_id, v_content_attr_id, v_subscription.actor_id);

    if v_subscription.content is distinct from v_new_content then
      declare
        v_content_diff jsonb;
        v_add jsonb;
        v_remove jsonb;
      begin
        v_content_diff := data.calc_content_diff(v_subscription.content, v_new_content);

        v_add := json.get_array(v_content_diff, 'add');
        v_remove := json.get_array(v_content_diff, 'remove');

        if v_add != jsonb '[]' or v_remove != jsonb '[]' then
          if v_remove != jsonb '[]' then
            -- Посылаем удаления только для видимых
            select jsonb_agg(a.value)
            into v_remove_list_changes
            from unnest(json.get_string_array(v_remove)) a(value)
            join data.objects o
              on o.code = a.value
            join data.client_subscription_objects cso
              on cso.object_id = o.id
              and cso.client_subscription_id = v_subscription.id
              and cso.is_visible is true;

            -- А вот удаляем реально все
            delete from data.client_subscription_objects
            where
              client_subscription_id = v_subscription.id and
              object_id in (
                select o.id
                from unnest(json.get_string_array(v_remove)) a(value)
                join data.objects o
                  on o.code = a.value);
          end if;

          if v_add != jsonb '[]' then
            declare
              v_processed_objects jsonb;
              v_add_element record;
              v_object_id integer;
              v_is_visible boolean;
              v_processed_object jsonb;
              v_index integer;
              v_position text;
              v_add_list_change jsonb;
            begin
              select jsonb_object_agg(o.code, jsonb_build_object('is_visible', cso.is_visible, 'index', cso.index))
              into v_processed_objects
              from data.client_subscription_objects cso
              join data.objects o
                on o.id = cso.object_id
              where cso.client_subscription_id = v_subscription.id;

              for v_add_element in
              (
                select
                  json.get_string(value, 'object_code') as object_code,
                  json.get_string_opt(value, 'position', null) as position
                from jsonb_array_elements(v_add) a(value)
              )
              loop
                -- Если клиенту не возвращался объект, указанный в position,
                -- то этот объект и все дальнейшие обрабатывать не нужно
                if not v_processed_objects ? v_add_element.position then
                  exit;
                end if;

                v_object_id := data.get_object_id(v_add_element.object_code);

                v_is_visible :=
                  json.get_boolean_opt(
                    data.get_attribute_value(
                      v_object_id,
                      'is_visible',
                      v_subscription.actor_id),
                    false);

                if v_add_element.position is not null then
                  v_processed_object := json.get_object(v_processed_objects, v_add_element.position);
                  v_index := json.get_integer(v_processed_object, 'index');
                  if json.get_boolean(v_processed_object, 'is_visible') then
                    v_position := v_add_element.position;
                  else
                    select o.code
                    into v_position
                    from data.client_subscription_objects cso
                    join data.objects o
                      on o.id = cso.object_id
                    where
                      cso.client_subscription_id = v_subscription.id and
                      cso.index = (
                        select min(index)
                        from data.client_subscription_objects
                        where
                          client_subscription_id = v_subscription.id and
                          index > v_index and
                          is_visible is true);
                  end if;

                  update data.client_subscription_objects
                  set index = index + 1
                  where
                    client_subscription_id = v_subscription.id and
                    index >= v_index;
                else
                  select coalesce(max(index) + 1, 1)
                  into v_index
                  from data.client_subscription_objects
                  where
                    client_subscription_id = v_subscription.id;
                end if;

                insert into data.client_subscription_objects(client_subscription_id, object_id, index, is_visible)
                values(v_subscription.id, data.get_object_id(v_add_element.object_code), v_index, v_is_visible);

                if v_is_visible then
                  v_add_list_change :=
                    jsonb_build_object(
                      'object',
                      data.get_object(v_object_id, v_subscription.actor_id, 'mini', v_subscription.object_id));
                  if v_position is not null then
                    v_add_list_change := v_add_list_change || jsonb_build_object('position', v_position);
                  end if;
                  v_add_list_changes := v_add_list_changes || v_add_list_change;
                end if;
              end loop;
            end;
          end if;
        end if;
      end;
    end if;

    if v_subscription.list_objects != jsonb '[]' then
      declare
        v_list record;
        v_mini_card_function text;
        v_new_list_data jsonb;
        v_add jsonb;
        v_position_object_id integer;
      begin
        for v_list in
        (
          select
            json.get_integer(value, 'id') as id,
            json.get_integer(value, 'object_id') as object_id,
            json.get_boolean(value, 'is_visible') as is_visible,
            json.get_integer(value, 'index') as index,
            json.get_object_opt(value, 'data', null) as data
          from jsonb_array_elements(v_subscription.list_objects)
          -- Удалённые из content'а мы уже обработали
          where json.get_integer(value, 'object_id') not in (
            select o.id
            from jsonb_array_elements(v_remove_list_changes) e
            join data.objects o on
              o.code = json.get_string(e.value))
        )
        loop
          v_mini_card_function :=
            json.get_string_opt(
              data.get_attribute_value(v_list.object_id, 'mini_card_function'),
              null);

          if v_mini_card_function is not null then
            execute format('select %s($1, $2)', v_mini_card_function)
            using v_list.object_id, v_subscription.actor_id;
          end if;

          if not json.get_boolean_opt(data.get_attribute_value(v_list.object_id, 'is_visible', v_subscription.actor_id), false) then
            if v_list.is_visible then
              v_set_invisible := array_append(v_set_invisible, v_list.id);

              v_remove_list_changes := v_remove_list_changes || to_jsonb(data.get_object_code(v_list.object_id));
            end if;
          else
            v_new_list_data := data.get_object(v_list.object_id, v_subscription.actor_id, 'mini', v_subscription.object_id);

            if not v_list.is_visible or v_new_list_data != v_list.data then
              if not v_list.is_visible then
                v_set_visible := array_append(v_set_visible, v_list.id);

                v_add := jsonb_build_object('object', v_new_list_data);

                select s.value
                into v_position_object_id
                from (
                  select first_value(object_id) over(order by index) as value
                  from data.client_subscription_objects
                  where
                    client_subscription_id = v_subscription.id and
                    index > v_list.index and
                    is_visible is true
                ) s
                limit 1;

                if v_position_object_id is not null then
                  v_add := v_add || jsonb_build_object('position', data.get_object_code(v_position_object_id));
                end if;

                v_add_list_changes := v_add_list_changes || v_add;
              else
                v_change_list_changes := v_change_list_changes || v_new_list_data;
              end if;
            end if;
          end if;
        end loop;
      end;
    end if;

    if v_remove_list_changes != jsonb '[]' then
      v_list_changes := v_list_changes || jsonb_build_object('remove', v_remove_list_changes);
    end if;

    if v_add_list_changes != jsonb '[]' then
      v_list_changes := v_list_changes || jsonb_build_object('add', v_add_list_changes);
    end if;

    if v_change_list_changes != jsonb '[]' then
      v_list_changes := v_list_changes || jsonb_build_object('change', v_change_list_changes);
    end if;

    if v_object is not null or v_list_changes != jsonb '{}' then
      v_ret_val_element := jsonb_build_object('object_id', v_subscription_object_code, 'client_id', v_subscription.client_id);

      if v_object is not null then
      v_ret_val_element := v_ret_val_element || jsonb_build_object('object', v_object);
      end if;

      if v_list_changes != jsonb '{}' then
        v_ret_val_element := v_ret_val_element || jsonb_build_object('list_changes', v_list_changes);
      end if;

      v_ret_val := v_ret_val || v_ret_val_element;
    end if;
  end loop;

  if v_set_visible is not null then
    update data.client_subscription_objects
    set is_visible = true
    where id = any(v_set_visible);
  end if;

  if v_set_invisible is not null then
    update data.client_subscription_objects
    set is_visible = false
    where id = any(v_set_invisible);
  end if;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function data_internal.save_state(integer[], integer);

create or replace function data_internal.save_state(in_subsciptions_ids integer[], in_filtered_list_object_id integer)
returns jsonb
volatile
as
$$
declare
  v_state jsonb := jsonb '[]';
  v_content_attr_id integer;
  v_client record;
  v_actor_id integer;
  v_list_objects jsonb;
  v_list record;
  v_list_object jsonb;
  v_length integer;
  v_id integer;
  v_object_id integer;
begin
  if in_subsciptions_ids is null then
    return v_state;
  end if;

  v_content_attr_id := data.get_attribute_id('content');

  for v_client in
  (
    select client_id, array_agg(array[id, object_id]) client_subscriptions
    from data.client_subscriptions
    where id = any(in_subsciptions_ids)
    group by client_id
  )
  loop
    v_actor_id := data.get_active_actor_id(v_client.client_id);

    v_length := array_length(v_client.client_subscriptions, 1);
    for i in 1..v_length loop
      v_list_objects := jsonb '[]';
      v_id := v_client.client_subscriptions[i][1];
      v_object_id := v_client.client_subscriptions[i][2];

      for v_list in
      (
        select
          id,
          object_id,
          is_visible,
          index
        from data.client_subscription_objects
        where
          client_subscription_id = v_id and
          (in_filtered_list_object_id is null or object_id != in_filtered_list_object_id)
      )
      loop
        v_list_object :=
          jsonb_build_object(
            'id',
            v_list.id,
            'object_id',
            v_list.object_id,
            'is_visible',
            v_list.is_visible,
            'index',
            v_list.index);

        if v_list.is_visible then
          v_list_object :=
            v_list_object ||
              jsonb_build_object(
                'data',
                data.get_object(v_list.object_id, v_actor_id, 'mini', v_object_id));
        end if;

        v_list_objects := v_list_objects || v_list_object;
      end loop;

      v_state :=
        v_state ||
        jsonb_build_object(
          'id',
          v_id,
          'client_id',
          v_client.client_id,
          'actor_id',
          v_actor_id,
          'object_id',
          v_object_id,
          'data',
          data.get_object(v_object_id, v_actor_id, 'full', v_object_id),
          'content',
          data.get_attribute_value(v_object_id, v_content_attr_id, v_actor_id),
          'list_objects',
          v_list_objects);
    end loop;
  end loop;

  return v_state;
end;
$$
language plpgsql;

-- drop function error.raise_invalid_input_param_value(text);

create or replace function error.raise_invalid_input_param_value(in_message text)
returns bigint
immutable
as
$$
begin
  assert in_message is not null;

  raise '%', in_message using errcode = 'invalid_parameter_value';
end;
$$
language plpgsql;

-- drop function error.raise_invalid_input_param_value(text, text);

create or replace function error.raise_invalid_input_param_value(in_format text, in_param text)
returns bigint
immutable
as
$$
begin
  assert in_format is not null;
  assert in_param is not null;

  raise '%', format(in_format, in_param) using errcode = 'invalid_parameter_value';
end;
$$
language plpgsql;

-- drop function error.raise_invalid_input_param_value(text, text, text);

create or replace function error.raise_invalid_input_param_value(in_format text, in_param1 text, in_param2 text)
returns bigint
immutable
as
$$
begin
  assert in_format is not null;
  assert in_param1 is not null;
  assert in_param2 is not null;

  raise '%', format(in_format, in_param1, in_param2) using errcode = 'invalid_parameter_value';
end;
$$
language plpgsql;

-- drop function job_test_project.change_description(jsonb);

create or replace function job_test_project.change_description(in_params jsonb)
returns void
volatile
as
$$
begin
  perform data.change_object_and_notify(
    json.get_integer(in_params, 'object_id'),
    jsonb '[]' || data.attribute_change2jsonb('description', in_params->'name'));
end;
$$
language plpgsql;

-- drop function job_test_project.init();

create or replace function job_test_project.init()
returns void
volatile
as
$$
declare
  v_type_attribute_id integer := data.get_attribute_id('type');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_actions_function_attribute_id integer := data.get_attribute_id('actions_function');
  v_template_attribute_id integer := data.get_attribute_id('template');

  v_menu_id integer;
  v_notifications_id integer;

  v_description_attribute_id integer;
  v_state_attribute_id integer;
  v_object_id integer;
  v_default_login_id integer;
begin
  -- Пустой объект меню
  insert into data.objects(code) values('menu') returning id into v_menu_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_menu_id, v_type_attribute_id, jsonb '"menu"'),
  (v_menu_id, v_is_visible_attribute_id, jsonb 'true');

  -- Пустой список уведомлений
  insert into data.objects(code) values('notifications') returning id into v_notifications_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_notifications_id, v_type_attribute_id, jsonb '"notifications"'),
  (v_notifications_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_notifications_id, v_content_attribute_id, jsonb '[]');

  -- Атрибуты
  insert into data.attributes(code, type, card_type, can_be_overridden)
  values ('description', 'normal', null, true)
  returning id into v_description_attribute_id;

  insert into data.attributes(code, type, card_type, can_be_overridden)
  values ('state', 'hidden', null, true)
  returning id into v_state_attribute_id;

  -- Действия
  insert into data.actions(code, function) values
  ('start_countdown', 'job_test_project.start_countdown_action');

  -- И сам объект
  insert into data.objects(code) values('object') returning id into v_object_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_object_id, v_type_attribute_id, jsonb '"object"'),
  (v_object_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_object_id, v_state_attribute_id, jsonb '"state1"'),
  (v_object_id, v_description_attribute_id, jsonb '"Обратный отсчёт!"'),
  (v_object_id, v_template_attribute_id, jsonb '{"title": "title", "groups": [{"code": "general", "attributes": ["description"], "actions": ["action"]}]}'),
  (v_object_id, v_actions_function_attribute_id, jsonb '"job_test_project.start_countdown_action_generator"');

  -- Логин по умолчанию
  insert into data.logins(code) values('default_login') returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_object_id);

  insert into data.params(code, value, description)
  values('default_login_id', to_jsonb(v_default_login_id), 'Идентификатор логина по умолчанию');
end;
$$
language plpgsql;

-- drop function job_test_project.start_countdown_action(integer, text, jsonb, jsonb, jsonb);

create or replace function job_test_project.start_countdown_action(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_id integer := data.get_active_actor_id(in_client_id);
  v_time timestamp with time zone := now();
begin
  perform data.change_current_object(
    in_client_id,
    in_request_id,
    v_object_id,
    jsonb '[]' || data.attribute_change2jsonb('state', jsonb '"state2"') || data.attribute_change2jsonb('description', jsonb '"Ждём начала обратного отсчёта..."'));

  perform data.create_job(v_time + interval '4 second', 'job_test_project.change_description', format('{"name": "4", "object_id": %s}', v_object_id)::jsonb);
  perform data.create_job(v_time + interval '3 second', 'job_test_project.change_description', format('{"name": "5", "object_id": %s}', v_object_id)::jsonb);
  perform data.create_job(v_time + interval '5 second', 'job_test_project.change_description', format('{"name": "3", "object_id": %s}', v_object_id)::jsonb);
  perform data.create_job(v_time + interval '6 second', 'job_test_project.change_description', format('{"name": "2", "object_id": %s}', v_object_id)::jsonb);
  perform data.create_job(v_time + interval '7 second', 'job_test_project.change_description', format('{"name": "1", "object_id": %s}', v_object_id)::jsonb);
  perform data.create_job(v_time + interval '8 second', 'job_test_project.change_description', format('{"name": "Ignition!", "object_id": %s}', v_object_id)::jsonb);
end;
$$
language plpgsql;

-- drop function job_test_project.start_countdown_action_generator(integer, integer);

create or replace function job_test_project.start_countdown_action_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_state text := json.get_string(data.get_attribute_value(in_object_id, 'state', in_actor_id));
begin
  if v_state = 'state1' then
    return format('{"action": {"code": "start_countdown", "name": "Поехали!", "disabled": false, "params": %s}}', in_object_id)::jsonb;
  end if;

  return jsonb '{}';
end;
$$
language plpgsql;

-- drop function json.array_find(jsonb, jsonb, integer);

create or replace function json.array_find(in_array jsonb, in_value jsonb, in_position integer default 0)
returns integer
volatile
as
$$
declare
  v_size integer := jsonb_array_length(in_array);
  v_position integer := in_position;
begin
  assert v_size is not null;
  assert in_value is not null;
  assert v_position is not null;

  while v_position < v_size loop
    if in_array->v_position = in_value then
      return v_position;
    end if;

    v_position := v_position + 1;
  end loop;

  return null;
end;
$$
language plpgsql;

-- drop function json.get_array(json, text);

create or replace function json.get_array(in_json json, in_name text default null::text)
returns json
immutable
as
$$
declare
  v_param json;
  v_param_type text;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := json_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      perform error.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'array' then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not an array', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'array' then
    perform error.raise_invalid_input_param_value('Json is not an array');
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_array(jsonb, text);

create or replace function json.get_array(in_json jsonb, in_name text default null::text)
returns jsonb
immutable
as
$$
declare
  v_param jsonb;
  v_param_type text;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := jsonb_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      perform error.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'array' then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not an array', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'array' then
    perform error.raise_invalid_input_param_value('Json is not an array');
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_array_opt(json, json);

create or replace function json.get_array_opt(in_json json, in_default json)
returns json
immutable
as
$$
declare
  v_default_type text;
  v_json_type text;
begin
  v_default_type := json_typeof(in_default);

  if v_default_type is not null and v_default_type != 'array' then
    raise exception 'Default value "%" is not an array', in_default::text;
  end if;

  v_json_type := json_typeof(in_json);

  if v_json_type is null or v_json_type = 'null' then
    return in_default;
  end if;

  if v_json_type != 'array' then
    perform error.raise_invalid_input_param_value('Json is not an array');
  end if;

  return in_json;
end;
$$
language plpgsql;

-- drop function json.get_array_opt(json, text, json);

create or replace function json.get_array_opt(in_json json, in_name text, in_default json)
returns json
immutable
as
$$
declare
  v_default_type text;
  v_param json;
  v_param_type text;
begin
  assert in_name is not null;

  v_default_type := json_typeof(in_default);

  if v_default_type is not null and v_default_type != 'array' then
    raise exception 'Default value "%" is not an array', in_default::text;
  end if;

  v_param := json.get_object(in_json)->in_name;

  v_param_type := json_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'array' then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not an array', in_name);
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_array_opt(jsonb, jsonb);

create or replace function json.get_array_opt(in_json jsonb, in_default jsonb)
returns jsonb
immutable
as
$$
declare
  v_default_type text;
  v_json_type text;
begin
  v_default_type := jsonb_typeof(in_default);

  if v_default_type is not null and v_default_type != 'array' then
    raise exception 'Default value "%" is not an array', in_default::text;
  end if;

  v_json_type := jsonb_typeof(in_json);

  if v_json_type is null or v_json_type = 'null' then
    return in_default;
  end if;

  if v_json_type != 'array' then
    perform error.raise_invalid_input_param_value('Json is not an array');
  end if;

  return in_json;
end;
$$
language plpgsql;

-- drop function json.get_array_opt(jsonb, text, jsonb);

create or replace function json.get_array_opt(in_json jsonb, in_name text, in_default jsonb)
returns jsonb
immutable
as
$$
declare
  v_default_type text;
  v_param jsonb;
  v_param_type text;
begin
  assert in_name is not null;

  v_default_type := jsonb_typeof(in_default);

  if v_default_type is not null and v_default_type != 'array' then
    raise exception 'Default value "%" is not an array', in_default::text;
  end if;

  v_param := json.get_object(in_json)->in_name;

  v_param_type := jsonb_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'array' then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not an array', in_name);
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_bigint(json, text);

create or replace function json.get_bigint(in_json json, in_name text default null::text)
returns bigint
immutable
as
$$
declare
  v_param json;
  v_param_type text;
  v_ret_val bigint;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := json_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      perform error.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'number' then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'number' then
    perform error.raise_invalid_input_param_value('Json is not a number');
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    if in_name is not null then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not a bigint', in_name);
    else
      perform error.raise_invalid_input_param_value('Json is not a bigint');
    end if;
  end;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function json.get_bigint(jsonb, text);

create or replace function json.get_bigint(in_json jsonb, in_name text default null::text)
returns bigint
immutable
as
$$
declare
  v_param jsonb;
  v_param_type text;
  v_ret_val bigint;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := jsonb_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      perform error.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'number' then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'number' then
    perform error.raise_invalid_input_param_value('Json is not a number');
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    if in_name is not null then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not a bigint', in_name);
    else
      perform error.raise_invalid_input_param_value('Json is not a bigint');
    end if;
  end;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function json.get_bigint_array(json, text);

create or replace function json.get_bigint_array(in_json json, in_name text default null::text)
returns bigint[]
immutable
as
$$
declare
  v_array json := json.get_array(in_json, in_name);
  v_array_len integer := json_array_length(v_array);
  v_ret_val bigint[] := array[]::bigint[];
begin
  for i in 0 .. v_array_len - 1 loop
    v_ret_val := array_append(v_ret_val, json.get_bigint(v_array->i));
  end loop;

  return v_ret_val;
exception when invalid_parameter_value then
  if in_name is not null then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a bigint array', in_name);
  else
    perform error.raise_invalid_input_param_value('Json is not a bigint array');
  end if;
end;
$$
language plpgsql;

-- drop function json.get_bigint_array(jsonb, text);

create or replace function json.get_bigint_array(in_json jsonb, in_name text default null::text)
returns bigint[]
immutable
as
$$
declare
  v_array jsonb := json.get_array(in_json, in_name);
  v_array_len integer := jsonb_array_length(v_array);
  v_ret_val bigint[] := array[]::bigint[];
begin
  for i in 0 .. v_array_len - 1 loop
    v_ret_val := array_append(v_ret_val, json.get_bigint(v_array->i));
  end loop;

  return v_ret_val;
exception when invalid_parameter_value then
  if in_name is not null then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a bigint array', in_name);
  else
    perform error.raise_invalid_input_param_value('Json is not a bigint array');
  end if;
end;
$$
language plpgsql;

-- drop function json.get_bigint_array_opt(json, bigint[]);

create or replace function json.get_bigint_array_opt(in_json json, in_default bigint[])
returns bigint[]
immutable
as
$$
declare
  v_array json := json.get_array_opt(in_json, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_bigint_array(v_array);
end;
$$
language plpgsql;

-- drop function json.get_bigint_array_opt(json, text, bigint[]);

create or replace function json.get_bigint_array_opt(in_json json, in_name text, in_default bigint[])
returns bigint[]
immutable
as
$$
declare
  v_array json := json.get_array_opt(in_json, in_name, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_bigint_array(in_json, in_name);
end;
$$
language plpgsql;

-- drop function json.get_bigint_array_opt(jsonb, bigint[]);

create or replace function json.get_bigint_array_opt(in_json jsonb, in_default bigint[])
returns bigint[]
immutable
as
$$
declare
  v_array jsonb := json.get_array_opt(in_json, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_bigint_array(v_array);
end;
$$
language plpgsql;

-- drop function json.get_bigint_array_opt(jsonb, text, bigint[]);

create or replace function json.get_bigint_array_opt(in_json jsonb, in_name text, in_default bigint[])
returns bigint[]
immutable
as
$$
declare
  v_array jsonb := json.get_array_opt(in_json, in_name, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_bigint_array(in_json, in_name);
end;
$$
language plpgsql;

-- drop function json.get_bigint_opt(json, bigint);

create or replace function json.get_bigint_opt(in_json json, in_default bigint)
returns bigint
immutable
as
$$
declare
  v_json_type text;
  v_ret_val bigint;
begin
  v_json_type := json_typeof(in_json);

  if v_json_type is null or v_json_type = 'null' then
    return in_default;
  end if;

  if v_json_type != 'number' then
    perform error.raise_invalid_input_param_value('Json is not a number');
  end if;

  begin
    v_ret_val := in_json;
  exception when others then
    perform error.raise_invalid_input_param_value('Json is not a bigint');
  end;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function json.get_bigint_opt(json, text, bigint);

create or replace function json.get_bigint_opt(in_json json, in_name text, in_default bigint)
returns bigint
immutable
as
$$
declare
  v_param json;
  v_param_type text;
  v_ret_val bigint;
begin
  assert in_name is not null;

  v_param := json.get_object(in_json)->in_name;

  v_param_type := json_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'number' then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a bigint', in_name);
  end;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function json.get_bigint_opt(jsonb, bigint);

create or replace function json.get_bigint_opt(in_json jsonb, in_default bigint)
returns bigint
immutable
as
$$
declare
  v_json_type text;
  v_ret_val bigint;
begin
  v_json_type := jsonb_typeof(in_json);

  if v_json_type is null or v_json_type = 'null' then
    return in_default;
  end if;

  if v_json_type != 'number' then
    perform error.raise_invalid_input_param_value('Json is not a number');
  end if;

  begin
    v_ret_val := in_json;
  exception when others then
    perform error.raise_invalid_input_param_value('Json is not a bigint');
  end;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function json.get_bigint_opt(jsonb, text, bigint);

create or replace function json.get_bigint_opt(in_json jsonb, in_name text, in_default bigint)
returns bigint
immutable
as
$$
declare
  v_param jsonb;
  v_param_type text;
  v_ret_val bigint;
begin
  assert in_name is not null;

  v_param := json.get_object(in_json)->in_name;

  v_param_type := jsonb_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'number' then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a bigint', in_name);
  end;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function json.get_boolean(json, text);

create or replace function json.get_boolean(in_json json, in_name text default null::text)
returns boolean
immutable
as
$$
declare
  v_param json;
  v_param_type text;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := json_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      perform error.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'boolean' then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not a boolean', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'boolean' then
    perform error.raise_invalid_input_param_value('Json is not a boolean');
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_boolean(jsonb, text);

create or replace function json.get_boolean(in_json jsonb, in_name text default null::text)
returns boolean
immutable
as
$$
declare
  v_param jsonb;
  v_param_type text;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := jsonb_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      perform error.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'boolean' then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not a boolean', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'boolean' then
    perform error.raise_invalid_input_param_value('Json is not a boolean');
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_boolean_array(json, text);

create or replace function json.get_boolean_array(in_json json, in_name text default null::text)
returns boolean[]
immutable
as
$$
declare
  v_array json := json.get_array(in_json, in_name);
  v_array_len integer := json_array_length(v_array);
  v_ret_val boolean[] := array[]::boolean[];
begin
  for i in 0 .. v_array_len - 1 loop
    v_ret_val := array_append(v_ret_val, json.get_boolean(v_array->i));
  end loop;

  return v_ret_val;
exception when invalid_parameter_value then
  if in_name is not null then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a boolean array', in_name);
  else
    perform error.raise_invalid_input_param_value('Json is not a boolean array');
  end if;
end;
$$
language plpgsql;

-- drop function json.get_boolean_array(jsonb, text);

create or replace function json.get_boolean_array(in_json jsonb, in_name text default null::text)
returns boolean[]
immutable
as
$$
declare
  v_array jsonb := json.get_array(in_json, in_name);
  v_array_len integer := jsonb_array_length(v_array);
  v_ret_val boolean[] := array[]::boolean[];
begin
  for i in 0 .. v_array_len - 1 loop
    v_ret_val := array_append(v_ret_val, json.get_boolean(v_array->i));
  end loop;

  return v_ret_val;
exception when invalid_parameter_value then
  if in_name is not null then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a boolean array', in_name);
  else
    perform error.raise_invalid_input_param_value('Json is not a boolean array');
  end if;
end;
$$
language plpgsql;

-- drop function json.get_boolean_array_opt(json, boolean[]);

create or replace function json.get_boolean_array_opt(in_json json, in_default boolean[])
returns boolean[]
immutable
as
$$
declare
  v_array json := json.get_array_opt(in_json, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_boolean_array(v_array);
end;
$$
language plpgsql;

-- drop function json.get_boolean_array_opt(json, text, boolean[]);

create or replace function json.get_boolean_array_opt(in_json json, in_name text, in_default boolean[])
returns boolean[]
immutable
as
$$
declare
  v_array json := json.get_array_opt(in_json, in_name, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_boolean_array(in_json, in_name);
end;
$$
language plpgsql;

-- drop function json.get_boolean_array_opt(jsonb, boolean[]);

create or replace function json.get_boolean_array_opt(in_json jsonb, in_default boolean[])
returns boolean[]
immutable
as
$$
declare
  v_array jsonb := json.get_array_opt(in_json, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_boolean_array(v_array);
end;
$$
language plpgsql;

-- drop function json.get_boolean_array_opt(jsonb, text, boolean[]);

create or replace function json.get_boolean_array_opt(in_json jsonb, in_name text, in_default boolean[])
returns boolean[]
immutable
as
$$
declare
  v_array jsonb := json.get_array_opt(in_json, in_name, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_boolean_array(in_json, in_name);
end;
$$
language plpgsql;

-- drop function json.get_boolean_opt(json, boolean);

create or replace function json.get_boolean_opt(in_json json, in_default boolean)
returns boolean
immutable
as
$$
declare
  v_json_type text;
begin
  v_json_type := json_typeof(in_json);

  if v_json_type is null or v_json_type = 'null' then
    return in_default;
  end if;

  if v_json_type != 'boolean' then
    perform error.raise_invalid_input_param_value('Json is not a boolean');
  end if;

  return in_json;
end;
$$
language plpgsql;

-- drop function json.get_boolean_opt(json, text, boolean);

create or replace function json.get_boolean_opt(in_json json, in_name text, in_default boolean)
returns boolean
immutable
as
$$
declare
  v_param json;
  v_param_type text;
begin
  assert in_name is not null;

  v_param := json.get_object(in_json)->in_name;

  v_param_type := json_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'boolean' then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a boolean', in_name);
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_boolean_opt(jsonb, boolean);

create or replace function json.get_boolean_opt(in_json jsonb, in_default boolean)
returns boolean
immutable
as
$$
declare
  v_json_type text;
begin
  v_json_type := jsonb_typeof(in_json);

  if v_json_type is null or v_json_type = 'null' then
    return in_default;
  end if;

  if v_json_type != 'boolean' then
    perform error.raise_invalid_input_param_value('Json is not a boolean');
  end if;

  return in_json;
end;
$$
language plpgsql;

-- drop function json.get_boolean_opt(jsonb, text, boolean);

create or replace function json.get_boolean_opt(in_json jsonb, in_name text, in_default boolean)
returns boolean
immutable
as
$$
declare
  v_param jsonb;
  v_param_type text;
begin
  assert in_name is not null;

  v_param := json.get_object(in_json)->in_name;

  v_param_type := jsonb_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'boolean' then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a boolean', in_name);
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_integer(json, text);

create or replace function json.get_integer(in_json json, in_name text default null::text)
returns integer
immutable
as
$$
declare
  v_param json;
  v_param_type text;
  v_ret_val integer;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := json_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      perform error.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'number' then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'number' then
    perform error.raise_invalid_input_param_value('Json is not a number');
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    if in_name is not null then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not an integer', in_name);
    else
      perform error.raise_invalid_input_param_value('Json is not an integer');
    end if;
  end;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function json.get_integer(jsonb, text);

create or replace function json.get_integer(in_json jsonb, in_name text default null::text)
returns integer
immutable
as
$$
declare
  v_param jsonb;
  v_param_type text;
  v_ret_val integer;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := jsonb_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      perform error.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'number' then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'number' then
    perform error.raise_invalid_input_param_value('Json is not a number');
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    if in_name is not null then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not an integer', in_name);
    else
      perform error.raise_invalid_input_param_value('Json is not an integer');
    end if;
  end;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function json.get_integer_array(json, text);

create or replace function json.get_integer_array(in_json json, in_name text default null::text)
returns integer[]
immutable
as
$$
declare
  v_array json := json.get_array(in_json, in_name);
  v_array_len integer := json_array_length(v_array);
  v_ret_val integer[] := array[]::integer[];
begin
  for i in 0 .. v_array_len - 1 loop
    v_ret_val := array_append(v_ret_val, json.get_integer(v_array->i));
  end loop;

  return v_ret_val;
exception when invalid_parameter_value then
  if in_name is not null then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not an integer array', in_name);
  else
    perform error.raise_invalid_input_param_value('Json is not an integer array');
  end if;
end;
$$
language plpgsql;

-- drop function json.get_integer_array(jsonb, text);

create or replace function json.get_integer_array(in_json jsonb, in_name text default null::text)
returns integer[]
immutable
as
$$
declare
  v_array jsonb := json.get_array(in_json, in_name);
  v_array_len integer := jsonb_array_length(v_array);
  v_ret_val integer[] := array[]::integer[];
begin
  for i in 0 .. v_array_len - 1 loop
    v_ret_val := array_append(v_ret_val, json.get_integer(v_array->i));
  end loop;

  return v_ret_val;
exception when invalid_parameter_value then
  if in_name is not null then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not an integer array', in_name);
  else
    perform error.raise_invalid_input_param_value('Json is not an integer array');
  end if;
end;
$$
language plpgsql;

-- drop function json.get_integer_array_opt(json, integer[]);

create or replace function json.get_integer_array_opt(in_json json, in_default integer[])
returns integer[]
immutable
as
$$
declare
  v_array json := json.get_array_opt(in_json, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_integer_array(v_array);
end;
$$
language plpgsql;

-- drop function json.get_integer_array_opt(json, text, integer[]);

create or replace function json.get_integer_array_opt(in_json json, in_name text, in_default integer[])
returns integer[]
immutable
as
$$
declare
  v_array json := json.get_array_opt(in_json, in_name, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_integer_array(in_json, in_name);
end;
$$
language plpgsql;

-- drop function json.get_integer_array_opt(jsonb, integer[]);

create or replace function json.get_integer_array_opt(in_json jsonb, in_default integer[])
returns integer[]
immutable
as
$$
declare
  v_array jsonb := json.get_array_opt(in_json, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_integer_array(v_array);
end;
$$
language plpgsql;

-- drop function json.get_integer_array_opt(jsonb, text, integer[]);

create or replace function json.get_integer_array_opt(in_json jsonb, in_name text, in_default integer[])
returns integer[]
immutable
as
$$
declare
  v_array jsonb := json.get_array_opt(in_json, in_name, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_integer_array(in_json, in_name);
end;
$$
language plpgsql;

-- drop function json.get_integer_opt(json, integer);

create or replace function json.get_integer_opt(in_json json, in_default integer)
returns integer
immutable
as
$$
declare
  v_json_type text;
  v_ret_val integer;
begin
  v_json_type := json_typeof(in_json);

  if v_json_type is null or v_json_type = 'null' then
    return in_default;
  end if;

  if v_json_type != 'number' then
    perform error.raise_invalid_input_param_value('Json is not a number');
  end if;

  begin
    v_ret_val := in_json;
  exception when others then
    perform error.raise_invalid_input_param_value('Json is not an integer');
  end;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function json.get_integer_opt(json, text, integer);

create or replace function json.get_integer_opt(in_json json, in_name text, in_default integer)
returns integer
immutable
as
$$
declare
  v_param json;
  v_param_type text;
  v_ret_val integer;
begin
  assert in_name is not null;

  v_param := json.get_object(in_json)->in_name;

  v_param_type := json_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'number' then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not an integer', in_name);
  end;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function json.get_integer_opt(jsonb, integer);

create or replace function json.get_integer_opt(in_json jsonb, in_default integer)
returns integer
immutable
as
$$
declare
  v_json_type text;
  v_ret_val integer;
begin
  v_json_type := jsonb_typeof(in_json);

  if v_json_type is null or v_json_type = 'null' then
    return in_default;
  end if;

  if v_json_type != 'number' then
    perform error.raise_invalid_input_param_value('Json is not a number');
  end if;

  begin
    v_ret_val := in_json;
  exception when others then
    perform error.raise_invalid_input_param_value('Json is not an integer');
  end;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function json.get_integer_opt(jsonb, text, integer);

create or replace function json.get_integer_opt(in_json jsonb, in_name text, in_default integer)
returns integer
immutable
as
$$
declare
  v_param jsonb;
  v_param_type text;
  v_ret_val integer;
begin
  assert in_name is not null;

  v_param := json.get_object(in_json)->in_name;

  v_param_type := jsonb_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'number' then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not an integer', in_name);
  end;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function json.get_number(json, text);

create or replace function json.get_number(in_json json, in_name text default null::text)
returns double precision
immutable
as
$$
declare
  v_param json;
  v_param_type text;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := json_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      perform error.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'number' then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'number' then
    perform error.raise_invalid_input_param_value('Json is not a number');
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_number(jsonb, text);

create or replace function json.get_number(in_json jsonb, in_name text default null::text)
returns double precision
immutable
as
$$
declare
  v_param jsonb;
  v_param_type text;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := jsonb_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      perform error.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'number' then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'number' then
    perform error.raise_invalid_input_param_value('Json is not a number');
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_number_array(json, text);

create or replace function json.get_number_array(in_json json, in_name text default null::text)
returns double precision[]
immutable
as
$$
declare
  v_array json := json.get_array(in_json, in_name);
  v_array_len integer := json_array_length(v_array);
  v_ret_val double precision[] := array[]::double precision[];
begin
  for i in 0 .. v_array_len - 1 loop
    v_ret_val := array_append(v_ret_val, json.get_number(v_array->i));
  end loop;

  return v_ret_val;
exception when invalid_parameter_value then
  if in_name is not null then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a number array', in_name);
  else
    perform error.raise_invalid_input_param_value('Json is not a number array');
  end if;
end;
$$
language plpgsql;

-- drop function json.get_number_array(jsonb, text);

create or replace function json.get_number_array(in_json jsonb, in_name text default null::text)
returns double precision[]
immutable
as
$$
declare
  v_array jsonb := json.get_array(in_json, in_name);
  v_array_len integer := jsonb_array_length(v_array);
  v_ret_val double precision[] := array[]::double precision[];
begin
  for i in 0 .. v_array_len - 1 loop
    v_ret_val := array_append(v_ret_val, json.get_number(v_array->i));
  end loop;

  return v_ret_val;
exception when invalid_parameter_value then
  if in_name is not null then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a number array', in_name);
  else
    perform error.raise_invalid_input_param_value('Json is not a number array');
  end if;
end;
$$
language plpgsql;

-- drop function json.get_number_array_opt(json, double precision[]);

create or replace function json.get_number_array_opt(in_json json, in_default double precision[])
returns double precision[]
immutable
as
$$
declare
  v_array json := json.get_array_opt(in_json, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_number_array(v_array);
end;
$$
language plpgsql;

-- drop function json.get_number_array_opt(json, text, double precision[]);

create or replace function json.get_number_array_opt(in_json json, in_name text, in_default double precision[])
returns double precision[]
immutable
as
$$
declare
  v_array json := json.get_array_opt(in_json, in_name, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_number_array(in_json, in_name);
end;
$$
language plpgsql;

-- drop function json.get_number_array_opt(jsonb, double precision[]);

create or replace function json.get_number_array_opt(in_json jsonb, in_default double precision[])
returns double precision[]
immutable
as
$$
declare
  v_array jsonb := json.get_array_opt(in_json, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_number_array(v_array);
end;
$$
language plpgsql;

-- drop function json.get_number_array_opt(jsonb, text, double precision[]);

create or replace function json.get_number_array_opt(in_json jsonb, in_name text, in_default double precision[])
returns double precision[]
immutable
as
$$
declare
  v_array jsonb := json.get_array_opt(in_json, in_name, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_number_array(in_json, in_name);
end;
$$
language plpgsql;

-- drop function json.get_number_opt(json, double precision);

create or replace function json.get_number_opt(in_json json, in_default double precision)
returns double precision
immutable
as
$$
declare
  v_json_type text;
begin
  v_json_type := json_typeof(in_json);

  if v_json_type is null or v_json_type = 'null' then
    return in_default;
  end if;

  if v_json_type != 'number' then
    perform error.raise_invalid_input_param_value('Json is not a number');
  end if;

  return in_json;
end;
$$
language plpgsql;

-- drop function json.get_number_opt(json, text, double precision);

create or replace function json.get_number_opt(in_json json, in_name text, in_default double precision)
returns double precision
immutable
as
$$
declare
  v_param json;
  v_param_type text;
begin
  assert in_name is not null;

  v_param := json.get_object(in_json)->in_name;

  v_param_type := json_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'number' then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_number_opt(jsonb, double precision);

create or replace function json.get_number_opt(in_json jsonb, in_default double precision)
returns double precision
immutable
as
$$
declare
  v_json_type text;
begin
  v_json_type := jsonb_typeof(in_json);

  if v_json_type is null or v_json_type = 'null' then
    return in_default;
  end if;

  if v_json_type != 'number' then
    perform error.raise_invalid_input_param_value('Json is not a number');
  end if;

  return in_json;
end;
$$
language plpgsql;

-- drop function json.get_number_opt(jsonb, text, double precision);

create or replace function json.get_number_opt(in_json jsonb, in_name text, in_default double precision)
returns double precision
immutable
as
$$
declare
  v_param jsonb;
  v_param_type text;
begin
  assert in_name is not null;

  v_param := json.get_object(in_json)->in_name;

  v_param_type := jsonb_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'number' then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_object(json, text);

create or replace function json.get_object(in_json json, in_name text default null::text)
returns json
immutable
as
$$
declare
  v_param json;
  v_param_type text;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := json_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      perform error.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'object' then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not an object', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'object' then
    perform error.raise_invalid_input_param_value('Json is not an object');
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_object(jsonb, text);

create or replace function json.get_object(in_json jsonb, in_name text default null::text)
returns jsonb
immutable
as
$$
declare
  v_param jsonb;
  v_param_type text;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := jsonb_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      perform error.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'object' then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not an object', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'object' then
    perform error.raise_invalid_input_param_value('Json is not an object');
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_object_array(json, text);

create or replace function json.get_object_array(in_json json, in_name text default null::text)
returns json
immutable
as
$$
declare
  v_array json := json.get_array(in_json, in_name);
  v_array_len integer := json_array_length(v_array);
begin
  for i in 0 .. v_array_len - 1 loop
    perform json.get_object(v_array->i);
  end loop;

  return v_array;
exception when invalid_parameter_value then
  if in_name is not null then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not an object array', in_name);
  else
    perform error.raise_invalid_input_param_value('Json is not an object array');
  end if;
end;
$$
language plpgsql;

-- drop function json.get_object_array(jsonb, text);

create or replace function json.get_object_array(in_json jsonb, in_name text default null::text)
returns jsonb
immutable
as
$$
declare
  v_array jsonb := json.get_array(in_json, in_name);
  v_array_len integer := jsonb_array_length(v_array);
begin
  for i in 0 .. v_array_len - 1 loop
    perform json.get_object(v_array->i);
  end loop;

  return v_array;
exception when invalid_parameter_value then
  if in_name is not null then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not an object array', in_name);
  else
    perform error.raise_invalid_input_param_value('Json is not an object array');
  end if;
end;
$$
language plpgsql;

-- drop function json.get_object_array_opt(json, json);

create or replace function json.get_object_array_opt(in_json json, in_default json)
returns json
immutable
as
$$
declare
  v_default_type text;
  v_array json;
begin
  if in_default is not null then
    begin
      perform json.get_object_array(in_default);
    exception when invalid_parameter_value then
      raise exception 'Default value "%" is not an object array', in_default::text;
    end;
  end if;

  v_array := json.get_array_opt(in_json, null);
  if v_array is null then
    return in_default;
  end if;

  return json.get_object_array(v_array);
end;
$$
language plpgsql;

-- drop function json.get_object_array_opt(json, text, json);

create or replace function json.get_object_array_opt(in_json json, in_name text, in_default json)
returns json
immutable
as
$$
declare
  v_default_type text;
  v_array json;
begin
  assert in_name is not null;

  if in_default is not null then
    begin
      perform json.get_object_array(in_default);
    exception when invalid_parameter_value then
      raise exception 'Default value "%" is not an object array', in_default::text;
    end;
  end if;

  v_array := json.get_array_opt(in_json, in_name, null);
  if v_array is null then
    return in_default;
  end if;

  return json.get_object_array(in_json, in_name);
end;
$$
language plpgsql;

-- drop function json.get_object_array_opt(jsonb, jsonb);

create or replace function json.get_object_array_opt(in_json jsonb, in_default jsonb)
returns jsonb
immutable
as
$$
declare
  v_default_type text;
  v_array jsonb;
begin
  if in_default is not null then
    begin
      perform json.get_object_array(in_default);
    exception when invalid_parameter_value then
      raise exception 'Default value "%" is not an object array', in_default::text;
    end;
  end if;

  v_array := json.get_array_opt(in_json, null);
  if v_array is null then
    return in_default;
  end if;

  return json.get_object_array(v_array);
end;
$$
language plpgsql;

-- drop function json.get_object_array_opt(jsonb, text, jsonb);

create or replace function json.get_object_array_opt(in_json jsonb, in_name text, in_default jsonb)
returns jsonb
immutable
as
$$
declare
  v_default_type text;
  v_array jsonb;
begin
  assert in_name is not null;

  if in_default is not null then
    begin
      perform json.get_object_array(in_default);
    exception when invalid_parameter_value then
      raise exception 'Default value "%" is not an object array', in_default::text;
    end;
  end if;

  v_array := json.get_array_opt(in_json, in_name, null);
  if v_array is null then
    return in_default;
  end if;

  return json.get_object_array(in_json, in_name);
end;
$$
language plpgsql;

-- drop function json.get_object_opt(json, json);

create or replace function json.get_object_opt(in_json json, in_default json)
returns json
immutable
as
$$
declare
  v_default_type text;
  v_json_type text;
begin
  v_default_type := json_typeof(in_default);

  if v_default_type is not null and v_default_type != 'object' then
    raise exception 'Default value "%" is not an object', in_default::text;
  end if;

  v_json_type := json_typeof(in_json);

  if v_json_type is null or v_json_type = 'null' then
    return in_default;
  end if;

  if v_json_type != 'object' then
    perform error.raise_invalid_input_param_value('Json is not an object');
  end if;

  return in_json;
end;
$$
language plpgsql;

-- drop function json.get_object_opt(json, text, json);

create or replace function json.get_object_opt(in_json json, in_name text, in_default json)
returns json
immutable
as
$$
declare
  v_default_type text;
  v_param json;
  v_param_type text;
begin
  assert in_name is not null;

  v_default_type := json_typeof(in_default);

  if v_default_type is not null and v_default_type != 'object' then
    raise exception 'Default value "%" is not an object', in_default::text;
  end if;

  v_param := json.get_object(in_json)->in_name;

  v_param_type := json_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'object' then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not an object', in_name);
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_object_opt(jsonb, jsonb);

create or replace function json.get_object_opt(in_json jsonb, in_default jsonb)
returns jsonb
immutable
as
$$
declare
  v_default_type text;
  v_json_type text;
begin
  v_default_type := jsonb_typeof(in_default);

  if v_default_type is not null and v_default_type != 'object' then
    raise exception 'Default value "%" is not an object', in_default::text;
  end if;

  v_json_type := jsonb_typeof(in_json);

  if v_json_type is null or v_json_type = 'null' then
    return in_default;
  end if;

  if v_json_type != 'object' then
    perform error.raise_invalid_input_param_value('Json is not an object');
  end if;

  return in_json;
end;
$$
language plpgsql;

-- drop function json.get_object_opt(jsonb, text, jsonb);

create or replace function json.get_object_opt(in_json jsonb, in_name text, in_default jsonb)
returns jsonb
immutable
as
$$
declare
  v_default_type text;
  v_param jsonb;
  v_param_type text;
begin
  assert in_name is not null;

  v_default_type := jsonb_typeof(in_default);

  if v_default_type is not null and v_default_type != 'object' then
    raise exception 'Default value "%" is not an object', in_default::text;
  end if;

  v_param := json.get_object(in_json)->in_name;

  v_param_type := jsonb_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'object' then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not an object', in_name);
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_string(json, text);

create or replace function json.get_string(in_json json, in_name text default null::text)
returns text
immutable
as
$$
declare
  v_param json;
  v_param_type text;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := json_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      perform error.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'string' then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not a string', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'string' then
    perform error.raise_invalid_input_param_value('Json is not a string');
  end if;

  return v_param#>>'{}';
end;
$$
language plpgsql;

-- drop function json.get_string(jsonb, text);

create or replace function json.get_string(in_json jsonb, in_name text default null::text)
returns text
immutable
as
$$
declare
  v_param jsonb;
  v_param_type text;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := jsonb_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      perform error.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'string' then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not a string', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'string' then
    perform error.raise_invalid_input_param_value('Json is not a string');
  end if;

  return v_param#>>'{}';
end;
$$
language plpgsql;

-- drop function json.get_string_array(json, text);

create or replace function json.get_string_array(in_json json, in_name text default null::text)
returns text[]
immutable
as
$$
declare
  v_array json := json.get_array(in_json, in_name);
  v_array_len integer := json_array_length(v_array);
  v_ret_val text[] := array[]::text[];
begin
  for i in 0 .. v_array_len - 1 loop
    v_ret_val := array_append(v_ret_val, json.get_string(v_array->i));
  end loop;

  return v_ret_val;
exception when invalid_parameter_value then
  if in_name is not null then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a string array', in_name);
  else
    perform error.raise_invalid_input_param_value('Json is not a string array');
  end if;
end;
$$
language plpgsql;

-- drop function json.get_string_array(jsonb, text);

create or replace function json.get_string_array(in_json jsonb, in_name text default null::text)
returns text[]
immutable
as
$$
declare
  v_array jsonb := json.get_array(in_json, in_name);
  v_array_len integer := jsonb_array_length(v_array);
  v_ret_val text[] := array[]::text[];
begin
  for i in 0 .. v_array_len - 1 loop
    v_ret_val := array_append(v_ret_val, json.get_string(v_array->i));
  end loop;

  return v_ret_val;
exception when invalid_parameter_value then
  if in_name is not null then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a string array', in_name);
  else
    perform error.raise_invalid_input_param_value('Json is not a string array');
  end if;
end;
$$
language plpgsql;

-- drop function json.get_string_array_opt(json, text, text[]);

create or replace function json.get_string_array_opt(in_json json, in_name text, in_default text[])
returns text[]
immutable
as
$$
declare
  v_array json := json.get_array_opt(in_json, in_name, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_string_array(in_json, in_name);
end;
$$
language plpgsql;

-- drop function json.get_string_array_opt(json, text[]);

create or replace function json.get_string_array_opt(in_json json, in_default text[])
returns text[]
immutable
as
$$
declare
  v_array json := json.get_array_opt(in_json, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_string_array(v_array);
end;
$$
language plpgsql;

-- drop function json.get_string_array_opt(jsonb, text, text[]);

create or replace function json.get_string_array_opt(in_json jsonb, in_name text, in_default text[])
returns text[]
immutable
as
$$
declare
  v_array jsonb := json.get_array_opt(in_json, in_name, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_string_array(in_json, in_name);
end;
$$
language plpgsql;

-- drop function json.get_string_array_opt(jsonb, text[]);

create or replace function json.get_string_array_opt(in_json jsonb, in_default text[])
returns text[]
immutable
as
$$
declare
  v_array jsonb := json.get_array_opt(in_json, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_string_array(v_array);
end;
$$
language plpgsql;

-- drop function json.get_string_opt(json, text);

create or replace function json.get_string_opt(in_json json, in_default text)
returns text
immutable
as
$$
declare
  v_json_type text;
begin
  v_json_type := json_typeof(in_json);

  if v_json_type is null or v_json_type = 'null' then
    return in_default;
  end if;

  if v_json_type != 'string' then
    perform error.raise_invalid_input_param_value('Json is not a string');
  end if;

  return in_json#>>'{}';
end;
$$
language plpgsql;

-- drop function json.get_string_opt(json, text, text);

create or replace function json.get_string_opt(in_json json, in_name text, in_default text)
returns text
immutable
as
$$
declare
  v_param json;
  v_param_type text;
begin
  assert in_name is not null;

  v_param := json.get_object(in_json)->in_name;

  v_param_type := json_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'string' then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a string', in_name);
  end if;

  return v_param#>>'{}';
end;
$$
language plpgsql;

-- drop function json.get_string_opt(jsonb, text);

create or replace function json.get_string_opt(in_json jsonb, in_default text)
returns text
immutable
as
$$
declare
  v_json_type text;
begin
  v_json_type := jsonb_typeof(in_json);

  if v_json_type is null or v_json_type = 'null' then
    return in_default;
  end if;

  if v_json_type != 'string' then
    perform error.raise_invalid_input_param_value('Json is not a string');
  end if;

  return in_json#>>'{}';
end;
$$
language plpgsql;

-- drop function json.get_string_opt(jsonb, text, text);

create or replace function json.get_string_opt(in_json jsonb, in_name text, in_default text)
returns text
immutable
as
$$
declare
  v_param jsonb;
  v_param_type text;
begin
  assert in_name is not null;

  v_param := json.get_object(in_json)->in_name;

  v_param_type := jsonb_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'string' then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a string', in_name);
  end if;

  return v_param#>>'{}';
end;
$$
language plpgsql;

-- drop function json.is_object_array(json, text);

create or replace function json.is_object_array(in_json json, in_name text default null::text)
returns boolean
immutable
as
$$
declare
  v_array json;
  v_array_len integer;
begin
  if in_name is not null then
    v_array := json.get_object(in_json)->in_name;
  else
    v_array = in_json;
  end if;

  if v_array is null or json_typeof(v_array) != 'array' then
    return false;
  end if;

  v_array_len := json_array_length(v_array);

  for i in 0 .. v_array_len - 1 loop
    if json_typeof(v_array->i) != 'object' then
      return false;
    end if;
  end loop;

  return true;
end;
$$
language plpgsql;

-- drop function json.is_object_array(jsonb, text);

create or replace function json.is_object_array(in_json jsonb, in_name text default null::text)
returns boolean
immutable
as
$$
declare
  v_array jsonb;
  v_array_len integer;
begin
  if in_name is not null then
    v_array := json.get_object(in_json)->in_name;
  else
    v_array = in_json;
  end if;

  if v_array is null or jsonb_typeof(v_array) != 'array' then
    return false;
  end if;

  v_array_len := jsonb_array_length(v_array);

  for i in 0 .. v_array_len - 1 loop
    if jsonb_typeof(v_array->i) != 'object' then
      return false;
    end if;
  end loop;

  return true;
end;
$$
language plpgsql;

-- drop function json.is_string_array(json, text);

create or replace function json.is_string_array(in_json json, in_name text default null::text)
returns boolean
immutable
as
$$
declare
  v_array json;
  v_array_len integer;
begin
  if in_name is not null then
    v_array := json.get_object(in_json)->in_name;
  else
    v_array = in_json;
  end if;

  if v_array is null or json_typeof(v_array) != 'array' then
    return false;
  end if;

  v_array_len := json_array_length(v_array);

  for i in 0 .. v_array_len - 1 loop
    if json_typeof(v_array->i) != 'string' then
      return false;
    end if;
  end loop;

  return true;
end;
$$
language plpgsql;

-- drop function json.is_string_array(jsonb, text);

create or replace function json.is_string_array(in_json jsonb, in_name text default null::text)
returns boolean
immutable
as
$$
declare
  v_array jsonb;
  v_array_len integer;
begin
  if in_name is not null then
    v_array := json.get_object(in_json)->in_name;
  else
    v_array = in_json;
  end if;

  if v_array is null or jsonb_typeof(v_array) != 'array' then
    return false;
  end if;

  v_array_len := jsonb_array_length(v_array);

  for i in 0 .. v_array_len - 1 loop
    if jsonb_typeof(v_array->i) != 'string' then
      return false;
    end if;
  end loop;

  return true;
end;
$$
language plpgsql;

-- drop function json_test.get_array_opt_should_throw_for_invalid_json_type();

create or replace function json_test.get_array_opt_should_throw_for_invalid_json_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''5''', '''"qwe"''', '''{}''', '''true'''] loop
      perform test.assert_throw(
        'select json.get_array_opt(' || v_json || '::' || v_json_type || ', null)',
        'Json is not an array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_array_opt_should_throw_for_invalid_param_type();

create or replace function json_test.get_array_opt_should_throw_for_invalid_param_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": 5}''', '''{"key": "qwe"}''', '''{"key": {}}''', '''{"key": true}'''] loop
      perform test.assert_throw(
        'select json.get_array_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
        '%key% is not an array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_array_should_throw_for_invalid_json_type();

create or replace function json_test.get_array_should_throw_for_invalid_json_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''5''', '''"qwe"''', '''{}''', '''true''', '''null'''] loop
      perform test.assert_throw(
        'select json.get_array(' || v_json || '::' || v_json_type || ')',
        'Json is not an array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_array_should_throw_for_invalid_param_type();

create or replace function json_test.get_array_should_throw_for_invalid_param_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": 5}''', '''{"key": "qwe"}''', '''{"key": {}}''', '''{"key": true}''', '''{"key": null}'''] loop
      perform test.assert_throw(
        'select json.get_array(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not an array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_bigint_array_opt_should_throw_for_invalid_json_elem_type();

create or replace function json_test.get_bigint_array_opt_should_throw_for_invalid_json_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[[]]''', '''["qwe"]''', '''[{}]''', '''[true]''', '''[null]'''] loop
      perform test.assert_throw(
        'select json.get_bigint_array_opt(' || v_json || '::' || v_json_type || ', null)',
        'Json is not a bigint array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_bigint_array_opt_should_throw_for_invalid_param_elem_type();

create or replace function json_test.get_bigint_array_opt_should_throw_for_invalid_param_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": [[]]}''', '''{"key": ["qwe"]}''', '''{"key": [{}]}''', '''{"key": [true]}''', '''{"key": [null]}'''] loop
      perform test.assert_throw(
        'select json.get_bigint_array_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
        '%key% is not a bigint array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_bigint_array_should_throw_for_invalid_json_elem_type();

create or replace function json_test.get_bigint_array_should_throw_for_invalid_json_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[[]]''', '''["qwe"]''', '''[{}]''', '''[true]''', '''[null]'''] loop
      perform test.assert_throw(
        'select json.get_bigint_array(' || v_json || '::' || v_json_type || ')',
        'Json is not a bigint array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_bigint_array_should_throw_for_invalid_param_elem_type();

create or replace function json_test.get_bigint_array_should_throw_for_invalid_param_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": [[]]}''', '''{"key": ["qwe"]}''', '''{"key": [{}]}''', '''{"key": [true]}''', '''{"key": [null]}'''] loop
      perform test.assert_throw(
        'select json.get_bigint_array(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not a bigint array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_bigint_opt_should_throw_for_float_json();

create or replace function json_test.get_bigint_opt_should_throw_for_float_json()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text := '''5.55''';
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    perform test.assert_throw(
      'select json.get_bigint_opt(' || v_json || '::' || v_json_type || ', null)',
      'Json is not a bigint');
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_bigint_opt_should_throw_for_float_param();

create or replace function json_test.get_bigint_opt_should_throw_for_float_param()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text := '''{"key": 5.55}''';
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    perform test.assert_throw(
      'select json.get_bigint_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
      '%key% is not a bigint');
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_bigint_opt_should_throw_for_invalid_json_type();

create or replace function json_test.get_bigint_opt_should_throw_for_invalid_json_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[]''', '''"qwe"''', '''{}''', '''true'''] loop
      perform test.assert_throw(
        'select json.get_bigint_opt(' || v_json || '::' || v_json_type || ', null)',
        'Json is not a number');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_bigint_opt_should_throw_for_invalid_param_type();

create or replace function json_test.get_bigint_opt_should_throw_for_invalid_param_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": []}''', '''{"key": "qwe"}''', '''{"key": {}}''', '''{"key": true}'''] loop
      perform test.assert_throw(
        'select json.get_bigint_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
        '%key% is not a number');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_bigint_should_throw_for_float_json();

create or replace function json_test.get_bigint_should_throw_for_float_json()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text := '''5.55''';
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    perform test.assert_throw(
      'select json.get_bigint(' || v_json || '::' || v_json_type || ')',
      'Json is not a bigint');
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_bigint_should_throw_for_float_param();

create or replace function json_test.get_bigint_should_throw_for_float_param()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text := '''{"key": 5.55}''';
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    perform test.assert_throw(
      'select json.get_bigint(' || v_json || '::' || v_json_type || ', ''key'')',
      '%key% is not a bigint');
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_bigint_should_throw_for_invalid_json_type();

create or replace function json_test.get_bigint_should_throw_for_invalid_json_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[]''', '''"qwe"''', '''{}''', '''true''', '''null'''] loop
      perform test.assert_throw(
        'select json.get_bigint(' || v_json || '::' || v_json_type || ')',
        'Json is not a number');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_bigint_should_throw_for_invalid_param_type();

create or replace function json_test.get_bigint_should_throw_for_invalid_param_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": []}''', '''{"key": "qwe"}''', '''{"key": {}}''', '''{"key": true}''', '''{"key": null}'''] loop
      perform test.assert_throw(
        'select json.get_bigint(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not a number');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_boolean_array_opt_should_throw_for_invalid_json_elem_type();

create or replace function json_test.get_boolean_array_opt_should_throw_for_invalid_json_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[[]]''', '''["qwe"]''', '''[{}]''', '''[5]''', '''[null]'''] loop
      perform test.assert_throw(
        'select json.get_boolean_array_opt(' || v_json || '::' || v_json_type || ', null)',
        'Json is not a boolean array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_boolean_array_opt_should_throw_for_invalid_param_elem_type();

create or replace function json_test.get_boolean_array_opt_should_throw_for_invalid_param_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": [[]]}''', '''{"key": ["qwe"]}''', '''{"key": [{}]}''', '''{"key": [5]}''', '''{"key": [null]}'''] loop
      perform test.assert_throw(
        'select json.get_boolean_array_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
        '%key% is not a boolean array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_boolean_array_should_throw_for_invalid_json_elem_type();

create or replace function json_test.get_boolean_array_should_throw_for_invalid_json_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[[]]''', '''["qwe"]''', '''[{}]''', '''[5]''', '''[null]'''] loop
      perform test.assert_throw(
        'select json.get_boolean_array(' || v_json || '::' || v_json_type || ')',
        'Json is not a boolean array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_boolean_array_should_throw_for_invalid_param_elem_type();

create or replace function json_test.get_boolean_array_should_throw_for_invalid_param_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": [[]]}''', '''{"key": ["qwe"]}''', '''{"key": [{}]}''', '''{"key": [5]}''', '''{"key": [null]}'''] loop
      perform test.assert_throw(
        'select json.get_boolean_array(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not a boolean array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_boolean_opt_should_throw_for_invalid_json_type();

create or replace function json_test.get_boolean_opt_should_throw_for_invalid_json_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''5''', '''[]''', '''"qwe"''', '''{}'''] loop
      perform test.assert_throw(
        'select json.get_boolean_opt(' || v_json || '::' || v_json_type || ', null)',
        'Json is not a boolean');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_boolean_opt_should_throw_for_invalid_param_type();

create or replace function json_test.get_boolean_opt_should_throw_for_invalid_param_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": 5}''', '''{"key": []}''', '''{"key": "qwe"}''', '''{"key": {}}'''] loop
      perform test.assert_throw(
        'select json.get_boolean_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
        '%key% is not a boolean');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_boolean_should_throw_for_invalid_json_type();

create or replace function json_test.get_boolean_should_throw_for_invalid_json_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''5''', '''[]''', '''"qwe"''', '''{}''', '''null'''] loop
      perform test.assert_throw(
        'select json.get_boolean(' || v_json || '::' || v_json_type || ')',
        'Json is not a boolean');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_boolean_should_throw_for_invalid_param_type();

create or replace function json_test.get_boolean_should_throw_for_invalid_param_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": 5}''', '''{"key": []}''', '''{"key": "qwe"}''', '''{"key": {}}''', '''{"key": null}'''] loop
      perform test.assert_throw(
        'select json.get_boolean(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not a boolean');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_integer_array_opt_should_throw_for_invalid_json_elem_type();

create or replace function json_test.get_integer_array_opt_should_throw_for_invalid_json_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[[]]''', '''["qwe"]''', '''[{}]''', '''[true]''', '''[null]'''] loop
      perform test.assert_throw(
        'select json.get_integer_array_opt(' || v_json || '::' || v_json_type || ', null)',
        'Json is not an integer array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_integer_array_opt_should_throw_for_invalid_param_elem_type();

create or replace function json_test.get_integer_array_opt_should_throw_for_invalid_param_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": [[]]}''', '''{"key": ["qwe"]}''', '''{"key": [{}]}''', '''{"key": [true]}''', '''{"key": [null]}'''] loop
      perform test.assert_throw(
        'select json.get_integer_array_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
        '%key% is not an integer array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_integer_array_should_throw_for_invalid_json_elem_type();

create or replace function json_test.get_integer_array_should_throw_for_invalid_json_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[[]]''', '''["qwe"]''', '''[{}]''', '''[true]''', '''[null]'''] loop
      perform test.assert_throw(
        'select json.get_integer_array(' || v_json || '::' || v_json_type || ')',
        'Json is not an integer array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_integer_array_should_throw_for_invalid_param_elem_type();

create or replace function json_test.get_integer_array_should_throw_for_invalid_param_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": [[]]}''', '''{"key": ["qwe"]}''', '''{"key": [{}]}''', '''{"key": [true]}''', '''{"key": [null]}'''] loop
      perform test.assert_throw(
        'select json.get_integer_array(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not an integer array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_integer_opt_should_throw_for_float_json();

create or replace function json_test.get_integer_opt_should_throw_for_float_json()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text := '''5.55''';
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    perform test.assert_throw(
      'select json.get_integer_opt(' || v_json || '::' || v_json_type || ', null)',
      'Json is not an integer');
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_integer_opt_should_throw_for_float_param();

create or replace function json_test.get_integer_opt_should_throw_for_float_param()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text := '''{"key": 5.55}''';
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    perform test.assert_throw(
      'select json.get_integer_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
      '%key% is not an integer');
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_integer_opt_should_throw_for_invalid_json_type();

create or replace function json_test.get_integer_opt_should_throw_for_invalid_json_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[]''', '''"qwe"''', '''{}''', '''true'''] loop
      perform test.assert_throw(
        'select json.get_integer_opt(' || v_json || '::' || v_json_type || ', null)',
        'Json is not a number');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_integer_opt_should_throw_for_invalid_param_type();

create or replace function json_test.get_integer_opt_should_throw_for_invalid_param_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": []}''', '''{"key": "qwe"}''', '''{"key": {}}''', '''{"key": true}'''] loop
      perform test.assert_throw(
        'select json.get_integer_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
        '%key% is not a number');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_integer_should_throw_for_float_json();

create or replace function json_test.get_integer_should_throw_for_float_json()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text := '''5.55''';
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    perform test.assert_throw(
      'select json.get_integer(' || v_json || '::' || v_json_type || ')',
      'Json is not an integer');
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_integer_should_throw_for_float_param();

create or replace function json_test.get_integer_should_throw_for_float_param()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text := '''{"key": 5.55}''';
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    perform test.assert_throw(
      'select json.get_integer(' || v_json || '::' || v_json_type || ', ''key'')',
      '%key% is not an integer');
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_integer_should_throw_for_invalid_json_type();

create or replace function json_test.get_integer_should_throw_for_invalid_json_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[]''', '''"qwe"''', '''{}''', '''true''', '''null'''] loop
      perform test.assert_throw(
        'select json.get_integer(' || v_json || '::' || v_json_type || ')',
        'Json is not a number');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_integer_should_throw_for_invalid_param_type();

create or replace function json_test.get_integer_should_throw_for_invalid_param_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": []}''', '''{"key": "qwe"}''', '''{"key": {}}''', '''{"key": true}''', '''{"key": null}'''] loop
      perform test.assert_throw(
        'select json.get_integer(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not a number');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_number_array_opt_should_throw_for_invalid_json_elem_type();

create or replace function json_test.get_number_array_opt_should_throw_for_invalid_json_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[[]]''', '''["qwe"]''', '''[{}]''', '''[true]''', '''[null]'''] loop
      perform test.assert_throw(
        'select json.get_number_array_opt(' || v_json || '::' || v_json_type || ', null)',
        'Json is not a number array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_number_array_opt_should_throw_for_invalid_param_elem_type();

create or replace function json_test.get_number_array_opt_should_throw_for_invalid_param_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": [[]]}''', '''{"key": ["qwe"]}''', '''{"key": [{}]}''', '''{"key": [true]}''', '''{"key": [null]}'''] loop
      perform test.assert_throw(
        'select json.get_number_array_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
        '%key% is not a number array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_number_array_should_throw_for_invalid_json_elem_type();

create or replace function json_test.get_number_array_should_throw_for_invalid_json_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[[]]''', '''["qwe"]''', '''[{}]''', '''[true]''', '''[null]'''] loop
      perform test.assert_throw(
        'select json.get_number_array(' || v_json || '::' || v_json_type || ')',
        'Json is not a number array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_number_array_should_throw_for_invalid_param_elem_type();

create or replace function json_test.get_number_array_should_throw_for_invalid_param_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": [[]]}''', '''{"key": ["qwe"]}''', '''{"key": [{}]}''', '''{"key": [true]}''', '''{"key": [null]}'''] loop
      perform test.assert_throw(
        'select json.get_number_array(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not a number array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_number_opt_should_throw_for_invalid_json_type();

create or replace function json_test.get_number_opt_should_throw_for_invalid_json_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[]''', '''"qwe"''', '''{}''', '''true'''] loop
      perform test.assert_throw(
        'select json.get_number_opt(' || v_json || '::' || v_json_type || ', null)',
        'Json is not a number');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_number_opt_should_throw_for_invalid_param_type();

create or replace function json_test.get_number_opt_should_throw_for_invalid_param_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": []}''', '''{"key": "qwe"}''', '''{"key": {}}''', '''{"key": true}'''] loop
      perform test.assert_throw(
        'select json.get_number_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
        '%key% is not a number');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_number_should_throw_for_invalid_json_type();

create or replace function json_test.get_number_should_throw_for_invalid_json_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[]''', '''"qwe"''', '''{}''', '''true''', '''null'''] loop
      perform test.assert_throw(
        'select json.get_number(' || v_json || '::' || v_json_type || ')',
        'Json is not a number');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_number_should_throw_for_invalid_param_type();

create or replace function json_test.get_number_should_throw_for_invalid_param_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": []}''', '''{"key": "qwe"}''', '''{"key": {}}''', '''{"key": true}''', '''{"key": null}'''] loop
      perform test.assert_throw(
        'select json.get_number(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not a number');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_object_array_opt_should_throw_for_invalid_json_elem_type();

create or replace function json_test.get_object_array_opt_should_throw_for_invalid_json_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[[]]''', '''["qwe"]''', '''[true]''', '''[5]''', '''[null]'''] loop
      perform test.assert_throw(
        'select json.get_object_array_opt(' || v_json || '::' || v_json_type || ', null)',
        'Json is not an object array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_object_array_opt_should_throw_for_invalid_param_elem_type();

create or replace function json_test.get_object_array_opt_should_throw_for_invalid_param_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": [[]]}''', '''{"key": ["qwe"]}''', '''{"key": [true]}''', '''{"key": [5]}''', '''{"key": [null]}'''] loop
      perform test.assert_throw(
        'select json.get_object_array_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
        '%key% is not an object array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_object_array_should_throw_for_invalid_json_elem_type();

create or replace function json_test.get_object_array_should_throw_for_invalid_json_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[[]]''', '''["qwe"]''', '''[true]''', '''[5]''', '''[null]'''] loop
      perform test.assert_throw(
        'select json.get_object_array(' || v_json || '::' || v_json_type || ')',
        'Json is not an object array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_object_array_should_throw_for_invalid_param_elem_type();

create or replace function json_test.get_object_array_should_throw_for_invalid_param_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": [[]]}''', '''{"key": ["qwe"]}''', '''{"key": [true]}''', '''{"key": [5]}''', '''{"key": [null]}'''] loop
      perform test.assert_throw(
        'select json.get_object_array(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not an object array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_object_opt_should_throw_for_invalid_json_type();

create or replace function json_test.get_object_opt_should_throw_for_invalid_json_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[]''', '''"qwe"''', '''5''', '''true'''] loop
      perform test.assert_throw(
        'select json.get_object_opt(' || v_json || '::' || v_json_type || ', null)',
        'Json is not an object');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_object_opt_should_throw_for_invalid_param_type();

create or replace function json_test.get_object_opt_should_throw_for_invalid_param_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": []}''', '''{"key": "qwe"}''', '''{"key": 5}''', '''{"key": true}'''] loop
      perform test.assert_throw(
        'select json.get_object_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
        '%key% is not an object');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_object_should_throw_for_invalid_json_type();

create or replace function json_test.get_object_should_throw_for_invalid_json_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[]''', '''"qwe"''', '''5''', '''true''', '''null'''] loop
      perform test.assert_throw(
        'select json.get_object(' || v_json || '::' || v_json_type || ')',
        'Json is not an object');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_object_should_throw_for_invalid_param_type();

create or replace function json_test.get_object_should_throw_for_invalid_param_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": []}''', '''{"key": "qwe"}''', '''{"key": 5}''', '''{"key": true}''', '''{"key": null}'''] loop
      perform test.assert_throw(
        'select json.get_object(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not an object');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_string_array_opt_should_throw_for_invalid_json_elem_type();

create or replace function json_test.get_string_array_opt_should_throw_for_invalid_json_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[[]]''', '''[{}]''', '''[true]''', '''[5]''', '''[null]'''] loop
      perform test.assert_throw(
        'select json.get_string_array_opt(' || v_json || '::' || v_json_type || ', null)',
        'Json is not a string array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_string_array_opt_should_throw_for_invalid_param_elem_type();

create or replace function json_test.get_string_array_opt_should_throw_for_invalid_param_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": [[]]}''', '''{"key": [{}]}''', '''{"key": [true]}''', '''{"key": [5]}''', '''{"key": [null]}'''] loop
      perform test.assert_throw(
        'select json.get_string_array_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
        '%key% is not a string array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_string_array_should_throw_for_invalid_json_elem_type();

create or replace function json_test.get_string_array_should_throw_for_invalid_json_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[[]]''', '''[{}]''', '''[true]''', '''[5]''', '''[null]'''] loop
      perform test.assert_throw(
        'select json.get_string_array(' || v_json || '::' || v_json_type || ')',
        'Json is not a string array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_string_array_should_throw_for_invalid_param_elem_type();

create or replace function json_test.get_string_array_should_throw_for_invalid_param_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": [[]]}''', '''{"key": [{}]}''', '''{"key": [true]}''', '''{"key": [5]}''', '''{"key": [null]}'''] loop
      perform test.assert_throw(
        'select json.get_string_array(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not a string array');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_string_opt_should_throw_for_invalid_json_type();

create or replace function json_test.get_string_opt_should_throw_for_invalid_json_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[]''', '''5''', '''{}''', '''true'''] loop
      perform test.assert_throw(
        'select json.get_string_opt(' || v_json || '::' || v_json_type || ', null)',
        'Json is not a string');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_string_opt_should_throw_for_invalid_param_type();

create or replace function json_test.get_string_opt_should_throw_for_invalid_param_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": []}''', '''{"key": 5}''', '''{"key": {}}''', '''{"key": true}'''] loop
      perform test.assert_throw(
        'select json.get_string_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
        '%key% is not a string');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_string_should_throw_for_invalid_json_type();

create or replace function json_test.get_string_should_throw_for_invalid_json_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[]''', '''5''', '''{}''', '''true''', '''null'''] loop
      perform test.assert_throw(
        'select json.get_string(' || v_json || '::' || v_json_type || ')',
        'Json is not a string');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_string_should_throw_for_invalid_param_type();

create or replace function json_test.get_string_should_throw_for_invalid_param_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": []}''', '''{"key": 5}''', '''{"key": {}}''', '''{"key": true}''', '''{"key": null}'''] loop
      perform test.assert_throw(
        'select json.get_string(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not a string');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_x_array_opt_should_throw_for_invalid_json_type();

create or replace function json_test.get_x_array_opt_should_throw_for_invalid_json_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_type in array array ['bigint', 'boolean', 'integer', 'object', 'string'] loop
      foreach v_json in array array ['''5''', '''"qwe"''', '''{}''', '''true'''] loop
        perform test.assert_throw(
          'select json.get_' || v_type || '_array_opt(' || v_json || '::' || v_json_type || ', null)',
          'Json is not an array');
      end loop;
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_x_array_opt_should_throw_for_invalid_param_type();

create or replace function json_test.get_x_array_opt_should_throw_for_invalid_param_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_type in array array ['bigint', 'boolean', 'integer', 'object', 'string'] loop
      foreach v_json in array array ['''{"key": 5}''', '''{"key": "qwe"}''', '''{"key": {}}''', '''{"key": true}'''] loop
        perform test.assert_throw(
          'select json.get_' || v_type || '_array_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
          '%key% is not an array');
      end loop;
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_x_array_should_throw_for_invalid_json_type();

create or replace function json_test.get_x_array_should_throw_for_invalid_json_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_type in array array ['bigint', 'boolean', 'integer', 'object', 'string'] loop
      foreach v_json in array array ['''5''', '''"qwe"''', '''{}''', '''true''', '''null'''] loop
        perform test.assert_throw(
          'select json.get_' || v_type || '_array(' || v_json || '::' || v_json_type || ')',
          'Json is not an array');
      end loop;
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_x_array_should_throw_for_invalid_param_type();

create or replace function json_test.get_x_array_should_throw_for_invalid_param_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_type in array array ['bigint', 'boolean', 'integer', 'object', 'string'] loop
      foreach v_json in array array ['''{"key": 5}''', '''{"key": "qwe"}''', '''{"key": {}}''', '''{"key": true}''', '''{"key": null}'''] loop
        perform test.assert_throw(
          'select json.get_' || v_type || '_array(' || v_json || '::' || v_json_type || ', ''key'')',
          '%key% is not an array');
      end loop;
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_x_opt_with_name_should_throw_for_null_json();

create or replace function json_test.get_x_opt_with_name_should_throw_for_null_json()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_type in array array ['array', 'bigint', 'bigint_array', 'boolean', 'boolean_array', 'integer', 'integer_array', 'object', 'object_array', 'string', 'string_array'] loop
      perform test.assert_throw(
        'select json.get_' || v_type || '_opt(null::' || v_json_type || ', ''key'', null)',
        'Json is not an object');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_x_should_throw_for_non_existing_key();

create or replace function json_test.get_x_should_throw_for_non_existing_key()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_type text;
  v_json text := '''{"key1": "value1", "key2": 2}''';
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_type in array array ['array', 'bigint', 'bigint_array', 'boolean', 'boolean_array', 'integer', 'integer_array', 'object', 'object_array', 'string', 'string_array'] loop
      perform test.assert_throw(
        'select json.get_' || v_type || '(' || v_json || '::' || v_json_type || ', ''key3'')',
        '%key3% not found');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function json_test.get_x_should_throw_for_null_json();

create or replace function json_test.get_x_should_throw_for_null_json()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_type in array array ['array', 'bigint', 'bigint_array', 'boolean', 'boolean_array', 'integer', 'integer_array', 'object', 'object_array', 'string', 'string_array'] loop
      perform test.assert_throw(
        'select json.get_' || v_type || '(null::' || v_json_type || ')',
        'Json is not a%');
    end loop;
    foreach v_type in array array ['array', 'bigint', 'bigint_array', 'boolean', 'boolean_array', 'integer', 'integer_array', 'object', 'object_array', 'string', 'string_array'] loop
      perform test.assert_throw(
        'select json.get_' || v_type || '(null::' || v_json_type || ', ''key'')',
        'Json is not an object');
    end loop;
  end loop;
end;
$$
language plpgsql;

-- drop function pallas_project.act_buy_lottery_ticket(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_buy_lottery_ticket(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_economy_type text := json.get_string(data.get_attribute_value_for_share(v_actor_id, 'system_person_economy_type'));
  v_price integer := data.get_integer_param('lottery_ticket_price');
  v_object_id integer := data.get_object_id('lottery');
  v_lottery_ticket_count integer := json.get_integer_opt(data.get_raw_attribute_value_for_update(v_object_id, 'lottery_ticket_count', v_actor_id), 0);
  v_current_sum bigint := json.get_bigint(data.get_attribute_value_for_update(v_actor_id, 'system_money'));
  v_lottery_status text := json.get_string(data.get_attribute_value_for_share(v_object_id, 'lottery_status'));
  v_diff jsonb;
  v_notified boolean;
begin
  assert in_request_id is not null;

  if v_economy_type != 'asters' then
    -- Потенциальный выигравший
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
    return;
  end if;

  if v_lottery_status != 'active' then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Лотерея заночилась', 'К сожалению, вы не успели, билеты более не продаются.');
    return;
  end if;

  if v_current_sum < v_price then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Не хватает денег', 'На вашем счету недостаточно средств для покупки лотерейных билетов.');
    return;
  end if;

  v_diff := pallas_project.change_money(v_actor_id, v_current_sum - v_price, v_actor_id, 'Status purchase');
  perform pallas_project.create_transaction(
    v_actor_id,
    'Покупка лотерейного билета',
    -v_price,
    v_current_sum - v_price,
    null,
    null,
    v_actor_id);
  v_diff :=
    v_diff ||
    data.change_object(
      v_object_id,
      jsonb '[]' || data.attribute_change2jsonb('lottery_ticket_count', to_jsonb(v_lottery_ticket_count + 1), v_actor_id),
      v_actor_id);

  v_notified :=
    data.process_diffs_and_notify_current_object(
      v_diff,
      in_client_id,
      in_request_id,
      v_object_id);
  assert v_notified;
end;
$$
language plpgsql;

-- drop function pallas_project.act_buy_status(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_buy_status(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_status_name text := json.get_string(in_params, 'status_name');
  v_status_value integer := json.get_integer(in_params, 'value');
  v_status_attribute_id integer = data.get_attribute_id('system_person_next_' || v_status_name || '_status');
  v_economy_type text := json.get_string(data.get_attribute_value_for_share(v_actor_id, 'system_person_economy_type'));
  v_currency_attribute_id integer = data.get_attribute_id(case when v_economy_type = 'un' then 'system_person_coin' else 'system_money' end);
  v_status_prices integer[] := data.get_integer_array_param(v_status_name || '_status_prices');
  v_current_status_value integer := json.get_integer(data.get_attribute_value_for_update(v_actor_id, v_status_attribute_id));
  v_current_sum bigint := json.get_bigint(data.get_attribute_value_for_update(v_actor_id, v_currency_attribute_id));
  v_price bigint;
  v_diff jsonb;
  v_notified boolean;
begin
  assert in_request_id is not null;
  assert in_user_params is null;
  assert in_default_params is null;

  select sum(v_status_prices[value])
  into v_price
  from unnest(array[1, 2, 3]) a(value)
  where
    value > v_current_status_value and
    value <= v_status_value;

  if v_economy_type != 'un' then
    v_price := v_price * data.get_integer_param('coin_price');
  end if;

  if v_current_status_value >= v_status_value or v_price > v_current_sum then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
    return;
  end if;

  if v_economy_type = 'un' then
    perform data.process_diffs_and_notify(
      pallas_project.change_coins(v_actor_id, (v_current_sum - v_price)::integer, v_actor_id, 'Status purchase'));
  else
    perform data.process_diffs_and_notify(
      pallas_project.change_money(v_actor_id, v_current_sum - v_price, v_actor_id, 'Status purchase'));
    perform pallas_project.create_transaction(
      v_actor_id,
      format(
        'Покупка %s статуса "%s"',
        (case when v_status_value = 1 then 'бронзового' when v_status_value = 2 then 'серебряного' else 'золотого' end),
        json.get_string(data.get_raw_attribute_value(data.get_class_id(v_status_name || '_status_page'), 'title'))),
      -v_price,
      v_current_sum - v_price,
      null,
      null,
      v_actor_id);
  end if;

  v_notified :=
    data.process_diffs_and_notify_current_object(
      pallas_project.change_next_status(v_actor_id, v_status_name, v_status_value, v_actor_id, 'Status purchase'),
      in_client_id,
      in_request_id,
      data.get_object_id(data.get_object_code(v_actor_id) || '_next_statuses'));
  -- Поменялся статус - уйдут кнопки
  assert v_notified;
end;
$$
language plpgsql;

-- drop function pallas_project.act_cancel_lottery(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_cancel_lottery(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_lottery_id integer := data.get_object_id('lottery');
  v_lottery_status text := json.get_string(data.get_attribute_value_for_update(v_lottery_id, 'lottery_status'));
  v_menu_attr integer := json.get_integer(data.get_attribute_value_for_update('menu', 'force_object_diff'));
  v_notified boolean;
begin
  assert in_request_id is not null;
  assert pp_utils.is_in_group(v_actor_id, 'master');

  if v_lottery_status = 'active' then
    v_notified :=
      data.change_current_object(
        in_client_id,
        in_request_id,
        v_lottery_id,
        jsonb '{"lottery_status": "cancelled"}',
        'Cancel lottery action');
    assert v_notified;
    perform data.change_object_and_notify(
      data.get_object_id('menu'),
      jsonb_build_object('force_object_diff', v_menu_attr + 1),
      v_actor_id,
      'Cancel lottery action');
    return;
  end if;

  perform api_utils.create_ok_notification(
    in_client_id,
    in_request_id);
end;
$$
language plpgsql;

-- drop function pallas_project.act_chat_change_settings(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_chat_change_settings(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_chat_code text := json.get_string(in_params, 'chat_code');
  v_parameter text := json.get_string(in_params, 'parameter');
  v_value text := json.get_string(in_params, 'value');
  v_chat_id integer := data.get_object_id(v_chat_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_master_group_id integer := data.get_object_id('master');
  v_chat_person_list_id integer := data.get_object_id(v_chat_code || '_person_list');

  v_changes jsonb[] := array[]::jsonb[];
  v_person_id integer;
  v_content text[];
  v_chat_parent_list text := json.get_string_opt(data.get_attribute_value(v_chat_id, 'system_chat_parent_list'), '~');
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;
  assert v_parameter in ('can_leave', 'can_invite', 'can_mute', 'can_rename');
  assert v_value in ('on', 'off');

  if v_parameter = 'can_leave' then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('system_chat_can_leave', case v_value when 'on' then null else to_jsonb(false) end));
  end if;
  if v_parameter = 'can_invite' then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('system_chat_can_invite', case v_value when 'on' then null else to_jsonb(false) end));
  end if;
  if v_parameter = 'can_mute' then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('system_chat_can_mute', case v_value when 'on' then null else to_jsonb(false) end));
    if v_value = 'off' then
      for v_person_id in 
        (select oo.object_id from data.object_objects oo 
         where oo.parent_object_id = v_chat_id
           and oo.parent_object_id <> oo.object_id)
      loop
        v_changes := array_append(v_changes, data.attribute_change2jsonb('chat_is_mute', null, v_person_id));
      end loop;
    end if;
  end if;
  if v_parameter = 'can_rename' then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('system_chat_can_rename', case v_value when 'on' then null else to_jsonb(false) end));
  end if;

  if array_length(v_changes, 1) > 0 then
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_chat_id, 
                                                 to_jsonb(v_changes));
  end if;

  if v_parameter = 'can_invite' then 
    v_content := pallas_project.get_chat_possible_persons(v_chat_id, (v_chat_parent_list = 'master_chats'));
    v_changes := array[]::jsonb[];
    if v_value = 'on' then
        v_changes := array_append(v_changes, data.attribute_change2jsonb('content', to_jsonb(v_content), v_master_group_id));
        v_changes := array_append(v_changes, data.attribute_change2jsonb('content', to_jsonb(v_content), v_chat_id));
        v_changes := array_append(v_changes, data.attribute_change2jsonb('chat_person_list_content_label', to_jsonb('-------------------------------
Кого добавляем?'::text), v_master_group_id));
        v_changes := array_append(v_changes, data.attribute_change2jsonb('chat_person_list_content_label', to_jsonb('-------------------------------
Кого добавляем?'::text), v_chat_id));
      elsif v_chat_parent_list <> 'master_chats' then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('content', to_jsonb(v_content), v_master_group_id));
      v_changes := array_append(v_changes, data.attribute_change2jsonb('content', null, v_chat_id));
      v_changes := array_append(v_changes, data.attribute_change2jsonb('chat_person_list_content_label', to_jsonb('-------------------------------
Кого добавляем?'::text), v_master_group_id));
      v_changes := array_append(v_changes, data.attribute_change2jsonb('chat_person_list_content_label', null, v_chat_id));
    else
      v_changes := array_append(v_changes, data.attribute_change2jsonb('content', null, v_master_group_id));
      v_changes := array_append(v_changes, data.attribute_change2jsonb('content', null, v_chat_id));
      v_changes := array_append(v_changes, data.attribute_change2jsonb('chat_person_list_content_label', null, v_master_group_id));
      v_changes := array_append(v_changes, data.attribute_change2jsonb('chat_person_list_content_label', null, v_chat_id));
    end if;
    perform data.change_object_and_notify(v_chat_person_list_id, 
                                          to_jsonb(v_changes),
                                          v_actor_id);
  end if;

  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_chat_enter(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_chat_enter(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string_opt(in_params, 'object_code', null);
  v_chat_code text := json.get_string_opt(in_params, 'chat_code', null);
  v_goto_chat boolean := json.get_boolean_opt(in_params, 'goto_chat', false);
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_chat_id integer;
  v_chat_parent_list text;

  v_name jsonb;
  v_chat_title text := '';
  v_chat_is_renamed boolean;
  v_chat_unread_messages_attribute_id integer := data.get_attribute_id('chat_unread_messages');

  v_chats_id integer := data.get_object_id('chats');
  v_master_chats_id integer := data.get_object_id('master_chats');

  v_is_master boolean := pp_utils.is_in_group(v_actor_id, 'master');
  v_changes jsonb[];
begin
  assert in_request_id is not null;
  assert v_object_code is not null or v_chat_code is not null;

  if v_object_code is not null then
    v_chat_id  := data.get_object_id(v_object_code || '_chat') ;
    v_chat_code := data.get_object_code(v_chat_id);
  elsif v_chat_code is not null then
    v_chat_id := data.get_object_id(v_chat_code);
  end if;

  v_chat_parent_list := json.get_string_opt(data.get_attribute_value(v_chat_id, 'system_chat_parent_list'), '~');

  --Проверяем, может мы уже в этом чате, тогда ничего делать не надо, только перейти
  if not pp_utils.is_in_group(v_actor_id, v_chat_code) then
  -- добавляем в группу с рассылкой
    perform data.process_diffs_and_notify(data.change_object_groups(v_actor_id, array[v_chat_id], array[]::integer[], v_actor_id));

    -- Меняем заголовок чата, если зашёл не мастер
    if not v_is_master or v_chat_parent_list = 'master_chats' then
      for v_name in 
        (select x.name from jsonb_to_recordset(pallas_project.get_chat_persons(v_chat_id, v_chat_parent_list <> 'master_chats'))as x(code text, name jsonb) limit 3) loop 
        v_chat_title := v_chat_title || ', '|| json.get_string(v_name);
      end loop;

      v_chat_title := trim(v_chat_title, ', ');

      v_changes := array[]::jsonb[];
      v_chat_is_renamed := json.get_boolean_opt(data.get_attribute_value_for_share(v_chat_id, 'system_chat_is_renamed'), false);
      if not v_chat_is_renamed then 
        v_changes := array_append(v_changes, data.attribute_change2jsonb('title', to_jsonb(v_chat_title)));
      else
        v_changes := array_append(v_changes, data.attribute_change2jsonb('subtitle', to_jsonb(v_chat_title)));
      end if;

      if v_object_code is not null or v_goto_chat then
        perform data.change_object_and_notify(v_chat_id, 
                                              to_jsonb(v_changes),
                                              null);
      else
        -- если мы заходили из самого чата, то надо прислать обновления себе
        perform data.change_current_object(in_client_id, 
                                           in_request_id, 
                                           v_chat_id, 
                                           to_jsonb(v_changes));
      end if;
      -- Меняем привязанный к чату список для участников
      perform pallas_project.change_chat_person_list_on_person(v_chat_id, case when not v_chat_is_renamed then v_chat_title else null end, (v_chat_parent_list = 'master_chats'));
    end if;

    if v_chat_parent_list = 'master_chats' then
      if not v_is_master then
        perform pp_utils.list_prepend_and_notify(v_master_chats_id, v_chat_code, v_actor_id);
      end if;
    elsif v_chat_parent_list = 'chats' then
      perform pp_utils.list_prepend_and_notify(v_chats_id, v_chat_code, v_actor_id);
    end if;
  end if;

  -- Переходим к чату или остаёмся на нём
  if v_object_code is not null or v_goto_chat then
    perform data.change_object_and_notify(v_chat_id, 
                                          jsonb_build_array(data.attribute_change2jsonb(v_chat_unread_messages_attribute_id, null, v_actor_id)),
                                          v_actor_id);

    perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_chat_code);
  else
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_chat_leave(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_chat_leave(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_chat_code text := json.get_string(in_params, 'chat_code');
  v_chat_id integer := data.get_object_id(v_chat_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_person_id integer;

  v_message_id integer;
  v_message_code text;
  v_message_class_id integer := data.get_class_id('message');

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_subtitle_attribute_id integer := data.get_attribute_id('subtitle');
  v_message_text_attribute_id integer := data.get_attribute_id('message_text');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_system_message_sender_attribute_id integer := data.get_attribute_id('system_message_sender');
  v_system_message_time_attribute_id integer := data.get_attribute_id('system_message_time');

  v_all_chats_id integer := data.get_object_id('all_chats');
  v_chats_id integer := data.get_object_id('chats');
  v_master_chats_id integer := data.get_object_id('master_chats');

  v_master_group_id integer := data.get_object_id('master');

  v_content text[];
  v_new_content text[];
  v_message_sent boolean := false;

  v_chat_bot_id integer := data.get_object_id('chat_bot');

  v_is_master boolean := pp_utils.is_in_group(v_actor_id, 'master');
  v_actor_title text := json.get_string(data.get_attribute_value(v_actor_id, v_title_attribute_id));
  v_title text := to_char(clock_timestamp(),'DD.MM hh24:mi:ss');
  v_chat_title text := json.get_string_opt(data.get_attribute_value(v_chat_id, v_title_attribute_id), null);
  v_chat_is_renamed boolean := json.get_boolean_opt(data.get_attribute_value_for_share(v_chat_id, 'system_chat_is_renamed'), false);
  v_chat_parent_list text := json.get_string_opt(data.get_attribute_value(v_chat_id, 'system_chat_parent_list'), '~');

  v_name jsonb;
  v_persons text:= '';
  v_changes jsonb[];
begin
  assert in_request_id is not null;

  -- проверяем, что выходить можно
  assert v_is_master or json.get_boolean_opt(data.get_attribute_value(v_actor_id, 'system_chat_can_leave'), true);

  -- Удаляемся из группы чата
  perform data.process_diffs_and_notify(data.change_object_groups(v_actor_id, array[]::integer[], array[v_chat_id], v_actor_id));

  -- Удаляем чат из своего списка чатов
  if v_chat_parent_list = 'master_chats' then
    if not v_is_master then
      perform pp_utils.list_remove_and_notify(v_master_chats_id, v_chat_code, v_actor_id);
    end if;
  else
    perform pp_utils.list_remove_and_notify(v_chats_id, v_chat_code, v_actor_id);
  end if;

  -- Мастера в чате не видно, поэтому светить его выход не надо
  if not v_is_master or v_chat_parent_list = 'master_chats' then
    -- Меняем список участников чата в заголовке
    for v_name in (select x.name from jsonb_to_recordset(pallas_project.get_chat_persons(v_chat_id, (v_chat_parent_list <> 'master_chats'))) as x(code text, name jsonb) limit 3) loop 
      v_persons := v_persons || ','|| json.get_string(v_name);
    end loop;
    v_persons := trim(v_persons, ',');

    v_changes := array[]::jsonb[];
    if not v_chat_is_renamed then
      v_changes := array_append(v_changes, data.attribute_change2jsonb(v_title_attribute_id, to_jsonb(v_persons)));
    else
      v_changes := array_append(v_changes, data.attribute_change2jsonb(v_subtitle_attribute_id, to_jsonb(v_persons)));
    end if;
    perform data.change_object_and_notify(v_chat_id, 
                                          to_jsonb(v_changes),
                                          v_actor_id);

    -- Меняем привязанный к чату список для участников
    perform pallas_project.change_chat_person_list_on_person(
      v_chat_id,
      case when not v_chat_is_renamed then v_persons else null end,
      (v_chat_parent_list = 'master_chats'));

    -- Создаём новое сообщение о том, что персонаж вышел из чата
    insert into data.objects(class_id) values (v_message_class_id) returning id, code into v_message_id, v_message_code;

    insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
    (v_message_id, v_title_attribute_id, to_jsonb(v_title), null),
    (v_message_id, v_message_text_attribute_id, to_jsonb(v_actor_title || ' вышел из чата'), null),
    (v_message_id, v_is_visible_attribute_id, jsonb 'true', v_chat_id),
    (v_message_id, v_system_message_sender_attribute_id, to_jsonb(v_chat_bot_id), null),
    (v_message_id, v_system_message_time_attribute_id, to_jsonb(to_char(clock_timestamp(),'DD.MM.YYYY hh24:mi:ss') ), null);

    -- Добавляем сообщение в чат
    perform pp_utils.list_prepend_and_notify(v_chat_id, v_message_code, null, v_chat_id);

    -- Перекладываем этот чат в начало в мастерском списке чатов
    if v_chat_parent_list = 'master_chats' then
      perform pp_utils.list_replace_to_head_and_notify(v_master_chats_id, v_chat_code, v_master_group_id);
    elsif v_chat_parent_list = 'chats' then
      perform pp_utils.list_replace_to_head_and_notify(v_all_chats_id, v_chat_code, v_master_group_id);
    end if;

    -- Отправляем нотификацию о новом сообщении всем неподписанным на этот чат
    -- и перекладываем у всех участников этот чат вверх списка
    for v_person_id in 
      (select oo.object_id from data.object_objects oo 
       where oo.parent_object_id = v_chat_id
         and oo.parent_object_id <> oo.object_id)
    loop
      if v_chat_parent_list = 'master_chats' then
        if not v_is_master then
          perform pp_utils.list_replace_to_head_and_notify(v_master_chats_id, v_chat_code, v_person_id);
        end if;
      elsif v_chat_parent_list = 'chats' then
        perform pp_utils.list_replace_to_head_and_notify(v_chats_id, v_chat_code, v_person_id);
      end if;
      if v_person_id <> v_actor_id 
        and not json.get_boolean_opt(data.get_attribute_value(v_chat_id, 'chat_is_mute', v_person_id), false) then
        perform pp_utils.add_notification_if_not_subscribed(v_person_id, v_actor_title || ' вышел из чата ' || v_chat_title, v_chat_id);
      end if;
    end loop;
  end if;

  -- Переходим к списку чатов
  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, 'chats');
end;
$$
language plpgsql;

-- drop function pallas_project.act_chat_mute(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_chat_mute(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_chat_code text := json.get_string(in_params, 'chat_code');
  v_mute_on_off text := json.get_string(in_params, 'mute_on_off');
  v_chat_id integer := data.get_object_id(v_chat_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_chat_is_mute boolean;
  v_new_chat_is_mute boolean;

  v_is_master boolean := pp_utils.is_in_group(v_actor_id, 'master');

  v_chat_is_mute_attribute_id integer := data.get_attribute_id('chat_is_mute');
  v_message_sent boolean := false;
begin
  -- mute_on_off: on - заглушить уведомления, off - перестать глушить уведомления
  assert in_request_id is not null;
  assert v_mute_on_off in ('on', 'off');

  v_chat_is_mute := json.get_boolean_opt(data.get_raw_attribute_value_for_update(v_chat_id, v_chat_is_mute_attribute_id, v_actor_id), false);

  if not v_chat_is_mute and v_mute_on_off = 'on' then
  -- проверяем, что отключать можно
    assert v_is_master or json.get_boolean_opt(data.get_attribute_value_for_share(v_actor_id, 'system_chat_can_mute'), true);
  end if;

  if v_mute_on_off = 'on' then
    v_new_chat_is_mute := true;
  end if;

  if coalesce(v_new_chat_is_mute, false) <> v_chat_is_mute then
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_chat_id, 
                                                 jsonb_build_array(data.attribute_change2jsonb(v_chat_is_mute_attribute_id, to_jsonb(v_new_chat_is_mute), v_actor_id)));
  end if;
  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_chat_rename(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_chat_rename(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_chat_code text := json.get_string(in_params, 'chat_code');
  v_title text := json.get_string(in_user_params, 'title');
  v_chat_id integer := data.get_object_id(v_chat_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_chat_person_list_id integer := data.get_object_id(v_chat_code || '_person_list');
  v_old_title text;
  v_chat_is_renamed boolean;
  v_changes jsonb[];

  v_subtitle_attribute_id integer := data.get_attribute_id('subtitle');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_system_chat_is_renamed_attribute_id integer := data.get_attribute_id('system_chat_is_renamed');
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;

  v_old_title := json.get_string_opt(data.get_raw_attribute_value_for_update(v_chat_id, v_title_attribute_id), '');
  v_chat_is_renamed := json.get_boolean_opt(data.get_attribute_value_for_update(v_chat_id, v_system_chat_is_renamed_attribute_id), false);

  if v_old_title <> v_title then
    v_changes := array[]::jsonb[];
    if not v_chat_is_renamed then
      v_changes := array_append(v_changes, data.attribute_change2jsonb(v_subtitle_attribute_id, to_jsonb(v_old_title)));
      v_changes := array_append(v_changes, data.attribute_change2jsonb(v_system_chat_is_renamed_attribute_id, to_jsonb(true)));
    end if;
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_title_attribute_id, to_jsonb(v_title)));
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_chat_id, 
                                                 to_jsonb(v_changes));

    v_changes := array[]::jsonb[];
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_title_attribute_id, to_jsonb('Участники чата ' || v_title)));
    perform data.change_object_and_notify(v_chat_person_list_id, to_jsonb(v_changes), v_actor_id);
  end if;

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_chat_write(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_chat_write(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_chat_code text := json.get_string(in_params, 'chat_code');
  v_chat_id integer := data.get_object_id(v_chat_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_person_id integer;

  v_message_text text := json.get_string(in_user_params, 'message_text');

  v_message_id integer;
  v_message_code text;
  v_message_class_id integer := data.get_class_id('message');

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_message_text_attribute_id integer := data.get_attribute_id('message_text');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_system_message_sender_attribute_id integer := data.get_attribute_id('system_message_sender');
  v_system_message_time_attribute_id integer := data.get_attribute_id('system_message_time');
  v_system_chat_length_attribute_id integer := data.get_attribute_id('system_chat_length');

  v_all_chats_id integer := data.get_object_id('all_chats');
  v_chats_id integer := data.get_object_id('chats');
  v_master_chats_id integer := data.get_object_id('master_chats');

  v_master_group_id integer := data.get_object_id('master');

  v_content text[];
  v_new_content text[];
  v_message_sent boolean := false;

  v_actor_title text := json.get_string(data.get_attribute_value(v_actor_id, v_title_attribute_id));
  v_title text := pp_utils.format_date(clock_timestamp()) || E'\n' || v_actor_title;

  v_chat_unread_messages integer;
  v_chat_unread_messages_attribute_id integer := data.get_attribute_id('chat_unread_messages');

  v_is_actor_subscribed boolean;
  v_chat_length integer;
  v_chat_parent_list text := json.get_string_opt(data.get_attribute_value(v_chat_id, 'system_chat_parent_list'), '~');
  v_chat_title text;
  v_changes jsonb[];
begin
  assert in_request_id is not null;

  -- Берём имя чата только если оно осознанное
  if json.get_boolean_opt(data.get_attribute_value_for_share(v_chat_id, 'system_chat_is_renamed'), false) then
    v_chat_title := json.get_string_opt(data.get_raw_attribute_value_for_share(v_chat_id, v_title_attribute_id), null);
  end if;
  -- создаём новое сообщение
  insert into data.objects(class_id) values (v_message_class_id) returning id, code into v_message_id, v_message_code;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_message_id, v_title_attribute_id, to_jsonb(v_title), null),
  (v_message_id, v_message_text_attribute_id, to_jsonb(v_message_text), null),
  (v_message_id, v_is_visible_attribute_id, jsonb 'true', v_chat_id),
  (v_message_id, v_system_message_sender_attribute_id, to_jsonb(v_actor_id), null),
  (v_message_id, v_system_message_time_attribute_id, to_jsonb(to_char(clock_timestamp(),'DD.MM.YYYY hh24:mi:ss') ), null);

  -- Добавляем сообщение в чат
  v_changes := array[]::jsonb[];

  -- Достаём, меняем, кладём назад
  v_content := json.get_string_array_opt(data.get_raw_attribute_value_for_update(v_chat_id, v_content_attribute_id), array[]::text[]);
  v_new_content := array_prepend(v_message_code, v_content);
  if v_new_content <> v_content then
    v_chat_length := json.get_integer_opt(data.get_attribute_value_for_update(v_chat_id, v_system_chat_length_attribute_id), null);
    if v_chat_length is not null then
      v_changes := array_append(v_changes, data.attribute_change2jsonb(v_system_chat_length_attribute_id, to_jsonb(v_chat_length + 1)));
    end if;
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_content_attribute_id, to_jsonb(v_new_content)));
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_chat_id, 
                                                 to_jsonb(v_changes));

    if v_chat_parent_list = 'master_chats' then
    -- Перекладываем этот чат в начало в списке мастерских чатов
      perform pp_utils.list_replace_to_head_and_notify(v_master_chats_id, v_chat_code, v_master_group_id);
    elsif v_chat_parent_list = 'chats' then
    -- Перекладываем этот чат в начало в списке всех игровых чатов
      perform pp_utils.list_replace_to_head_and_notify(v_all_chats_id, v_chat_code, v_master_group_id);
    end if;
    -- Отправляем нотификацию о новом сообщении всем неподписанным на этот чат
    -- и перекладываем у всех участников этот чат вверх списка
    for v_person_id in 
      (select oo.object_id from data.object_objects oo 
        where oo.parent_object_id = v_chat_id
          and oo.parent_object_id <> oo.object_id)
    loop
      if v_chat_parent_list = 'master_chats' then
        if pp_utils.is_in_group(v_person_id, 'master') then
          perform pp_utils.list_replace_to_head_and_notify(v_master_chats_id, v_chat_code, v_person_id);
        end if;
      elsif v_chat_parent_list = 'chats' then
        perform pp_utils.list_replace_to_head_and_notify(v_chats_id, v_chat_code, v_person_id);
      end if;
      v_is_actor_subscribed := pp_utils.is_actor_subscribed(v_person_id, v_chat_id);
      if v_person_id <> v_actor_id
        and not v_is_actor_subscribed then
        v_chat_unread_messages := json.get_integer_opt(data.get_raw_attribute_value_for_update(v_chat_id, v_chat_unread_messages_attribute_id, v_person_id), 0);
        perform data.change_object_and_notify(v_chat_id, 
                                              jsonb_build_array(data.attribute_change2jsonb(v_chat_unread_messages_attribute_id, to_jsonb(v_chat_unread_messages + 1), v_person_id)),
                                              v_actor_id);
      end if;
      if v_person_id <> v_actor_id 
        and not v_is_actor_subscribed
        and not json.get_boolean_opt(data.get_raw_attribute_value_for_share(v_chat_id, 'chat_is_mute', v_person_id), false) then
        perform pp_utils.add_notification(v_person_id, 'Новое сообщение ' || (case when v_chat_title is not null then ' в '|| v_chat_title  || ' ' else '' end) || 'от '|| v_actor_title , v_chat_id);
      end if;
    end loop;
  end if;

  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_clear_notifications(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_clear_notifications(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_notifications_id integer := data.get_object_id('notifications');
  v_notified boolean;
begin
  perform data.change_object_and_notify(
    v_actor_id,
    jsonb_build_object('system_person_notification_count', jsonb '0'),
    v_actor_id,
    'Open notification');

  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      v_notifications_id,
      jsonb '[]' || data.attribute_change2jsonb('content', jsonb '[]', v_actor_id),
      'Open notification');

  if not v_notified then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_create_chat(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_create_chat(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_chat_title text := json.get_string_opt(in_params, 'title', null);
  v_chat_is_master boolean := json.get_boolean_opt(in_params, 'chat_is_master', false);
  v_chat_code text;
  v_chat_id integer;
  v_chat_class_id integer := data.get_class_id('chat');

  v_all_chats_id integer := data.get_object_id('all_chats');
  v_master_chats_id integer := data.get_object_id('master_chats');
  v_master_group_id integer := data.get_object_id('master');

  v_attributes jsonb;
begin
  assert in_request_id is not null;

  v_attributes := jsonb_build_object(
                  'content', jsonb '[]',
                  'title', v_chat_title,
                  'system_chat_is_renamed', case when v_chat_title is not null then true else false end,
                  'system_chat_parent_list', case when v_chat_is_master then 'master_chats' else 'chats' end
                  );

  -- Создаём чат
  v_chat_id := pallas_project.create_chat(null, v_attributes);

  v_chat_code := data.get_object_code(v_chat_id);

  if v_chat_is_master then
    perform pp_utils.list_prepend_and_notify(v_master_chats_id, v_chat_code, v_master_group_id);
  else
    perform pp_utils.list_prepend_and_notify(v_all_chats_id, v_chat_code, v_master_group_id);
  end if;

  -- Заходим в чат
  perform pallas_project.act_chat_enter(in_client_id, in_request_id, jsonb_build_object('chat_code', v_chat_code, 'goto_chat', true), null, null);

end;
$$
language plpgsql;

-- drop function pallas_project.act_create_random_person(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_create_random_person(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_title text;

  v_person_id integer;
  v_login_id integer;

  v_first_names text[] := json.get_string_array(data.get_param('first_names'));
  v_last_names text[] := json.get_string_array(data.get_param('last_names'));

  v_title_attribute_id integer := data.get_attribute_id('title');

  v_all_person_group_id integer := data.get_object_id('all_person');
  v_player_group_id integer := data.get_object_id('player');

  v_person_class_id integer := data.get_class_id('person');
begin
  assert in_request_id is not null;

  v_title := v_first_names[random.random_integer(1, array_length(v_first_names, 1))] || ' '|| v_last_names[random.random_integer(1, array_length(v_last_names, 1))];
  insert into data.objects(class_id) values(v_person_class_id) returning id into v_person_id;
    -- Логин
  insert into data.logins default values returning id into v_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_login_id, v_person_id);
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_id, v_title_attribute_id, to_jsonb(v_title));

  insert into data.object_objects(parent_object_id, object_id) values
  (v_all_person_group_id, v_person_id),
  (v_player_group_id, v_person_id);

  -- Заменим логин
  perform data.set_login(in_client_id, v_login_id);
  -- И отправим новый список акторов
  perform api_utils.process_get_actors_message(in_client_id, in_request_id);
end;
$$
language plpgsql;

-- drop function pallas_project.act_debatle_change_audience_group(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_change_audience_group(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_debatle_code text := json.get_string(in_params, 'debatle_code');
  v_list_code text := json.get_string(in_params, 'list_code');
  v_add_or_del text := json.get_string(in_params, 'add_or_del');

  v_debatle_change_id integer := data.get_object_id(v_debatle_code || '_target_audience');
  v_debatle_id integer := data.get_object_id(v_debatle_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_list_id integer := data.get_object_id(v_list_code);

  v_system_debatle_target_audience text[] := json.get_string_array_opt(data.get_attribute_value_for_update(v_debatle_id, 'system_debatle_target_audience'), array[]::text[]);
  v_debatle_person1 text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person1'), null);
  v_debatle_target_audience text;

  v_force_object_diff integer := json.get_integer_opt(data.get_attribute_value_for_update(v_list_id, 'force_object_diff'), 0);

  v_changes jsonb[];
  v_message_sent boolean;
begin
  assert in_request_id is not null;
  assert v_add_or_del in ('add', 'del');

  if v_add_or_del = 'add' then
    v_system_debatle_target_audience := array_append(v_system_debatle_target_audience, v_list_code);
    perform data.add_object_to_object(v_list_id, v_debatle_id);
  else
    v_system_debatle_target_audience := array_remove(v_system_debatle_target_audience, v_list_code);
    perform data.remove_object_from_object(v_list_id, v_debatle_id);
  end if;

  v_debatle_target_audience := pallas_project.get_debatle_target_audience(v_system_debatle_target_audience);

  v_changes := array[]::jsonb[];
  v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_target_audience', to_jsonb(v_debatle_target_audience), 'master'));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_target_audience', to_jsonb(v_debatle_target_audience), v_debatle_person1));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_target_audience', to_jsonb(v_system_debatle_target_audience)));

  perform data.change_object_and_notify(v_debatle_id, to_jsonb(v_changes), v_actor_id);

  perform data.change_object_and_notify(v_list_id, jsonb_build_array(data.attribute_change2jsonb('force_object_diff', to_jsonb(v_force_object_diff + 1))), v_actor_id);

  v_changes := array[]::jsonb[];
  v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_target_audience', to_jsonb(v_debatle_target_audience)));
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               v_debatle_change_id, 
                                               to_jsonb(v_changes));
  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_debatle_change_bonuses(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_change_bonuses(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_debatle_code text := json.get_string(in_params, 'debatle_code');
  v_judged_person text := json.get_string_opt(in_params, 'judged_person', '~~~');
  v_debatle_id integer := data.get_object_id(v_debatle_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_debatle_status text;
  v_debatle_title text := json.get_string_opt(data.get_raw_attribute_value_for_share(v_debatle_id, 'title'), '');

  v_debatle_person_bonuses jsonb;

  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_debatle_temp_bonus_list_person_attribute_id integer := data.get_attribute_id('debatle_temp_bonus_list_person');
  v_system_debatle_temp_bonus_list_debatle_id_attribute_id integer := data.get_attribute_id('system_debatle_temp_bonus_list_debatle_id');
  v_debatle_temp_bonus_list_bonuses_attribute_id integer := data.get_attribute_id('debatle_temp_bonus_list_bonuses');
  v_debatle_bonus_votes_attribute_id integer:= data.get_attribute_id('debatle_bonus_votes');

  v_debatle_temp_bonus_list_class_id integer := data.get_class_id('debatle_temp_bonus_list');
  v_debatle_bonus_class_id integer := data.get_class_id('debatle_bonus');
  v_content text[];

  v_temp_object_code text;
  v_temp_object_id integer;
begin
  assert in_request_id is not null;

  if v_judged_person not in ('instigator', 'opponent') then
    perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Ошибка',
      'Непонятно, какой из персон начислять бонусы и штрафы. Наверное что-то пошло не так. Обратитесь к мастеру.');
    return;
  end if;

  if v_judged_person = 'instigator' then
    v_debatle_person_bonuses := coalesce(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person1_bonuses'), jsonb '[]');
  else
    v_debatle_person_bonuses := coalesce(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person2_bonuses'), jsonb '[]');
  end if;

  -- создаём темповый список бонусов и штрафов
  insert into data.objects(class_id) values (v_debatle_temp_bonus_list_class_id) returning id, code into v_temp_object_id, v_temp_object_code;

  select array_agg(o.code order by av_votes.value desc, av_title.value) into v_content
  from data.objects o
  left join data.attribute_values av_votes on av_votes.object_id = o.id and av_votes.attribute_id = v_debatle_bonus_votes_attribute_id and av_votes.value_object_id is null
  left join data.attribute_values av_title on av_title.object_id = o.id and av_title.attribute_id = v_title_attribute_id and av_title.value_object_id is null
  where o.class_id = v_debatle_bonus_class_id
    and o.code not in (select x.code from jsonb_to_recordset(v_debatle_person_bonuses) as x(code text, name text, votes int));

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_temp_object_id, v_title_attribute_id, to_jsonb(format('Изменение дебатла "%s"', v_debatle_title)), v_actor_id),
  (v_temp_object_id, v_is_visible_attribute_id, jsonb 'true', v_actor_id),
  (v_temp_object_id, v_debatle_temp_bonus_list_person_attribute_id, to_jsonb(v_judged_person), null),
  (v_temp_object_id, v_system_debatle_temp_bonus_list_debatle_id_attribute_id, to_jsonb(v_debatle_id), null),
  (v_temp_object_id, v_debatle_temp_bonus_list_bonuses_attribute_id, v_debatle_person_bonuses, null);

  if v_content is not null then
    insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
    (v_temp_object_id, v_content_attribute_id, to_jsonb(v_content), null);
  end  if;

  perform api_utils.create_open_object_action_notification(
    in_client_id,
    in_request_id,
    v_temp_object_code);
end;
$$
language plpgsql;

-- drop function pallas_project.act_debatle_change_other_bonus(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_change_other_bonus(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_debatle_change_code text := json.get_string(in_params, 'debatle_change_code');
  v_judged_person text := json.get_string_opt(in_params, 'judged_person', '~~~');
  v_bonus_or_fine text := json.get_string_opt(in_params, 'bonus_or_fine', '~~~');

  v_bonus_reason text := json.get_string_opt(in_user_params, 'bonus_reason', '~~~');
  v_votes integer := json.get_integer_opt(in_user_params, 'votes', 1);

  v_debatle_change_id integer := data.get_object_id(v_debatle_change_code);
  v_debatle_id integer := json.get_integer(data.get_attribute_value(v_debatle_change_id,'system_debatle_temp_bonus_list_debatle_id'));
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_debatle_person_bonuses jsonb;

  v_changes jsonb[];
  v_message_sent boolean;
begin
  assert in_request_id is not null;
  assert v_bonus_or_fine in ('bonus', 'fine');

  if v_bonus_or_fine = 'fine' then
    v_votes := (@ v_votes) *(-1);
  end if;

  if v_judged_person not in ('instigator', 'opponent') then
    perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Ошибка',
      'Непонятно, какой из персон начислять бонусы и штрафы. Наверное что-то пошло не так. Обратитесь к мастеру.');
    return;
  end if;

  if v_judged_person = 'instigator' then
    v_debatle_person_bonuses := coalesce(data.get_attribute_value_for_update(v_debatle_id, 'debatle_person1_bonuses'), jsonb '[]');
    v_debatle_person_bonuses := jsonb_insert(v_debatle_person_bonuses, '{1}', jsonb_build_object('code', 'other', 'name', v_bonus_reason, 'votes', v_votes));
    v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person1_bonuses', v_debatle_person_bonuses));
  elsif v_judged_person = 'opponent' then
    v_debatle_person_bonuses := coalesce(data.get_attribute_value_for_update(v_debatle_id, 'debatle_person2_bonuses'), jsonb '[]');
    v_debatle_person_bonuses := jsonb_insert(v_debatle_person_bonuses, '{1}', jsonb_build_object('code', 'other', 'name', v_bonus_reason, 'votes', v_votes));
    v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person2_bonuses', v_debatle_person_bonuses));
  end if;

  perform data.change_object_and_notify(v_debatle_id, to_jsonb(v_changes), v_actor_id);

  v_changes := array[]::jsonb[];
  v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_temp_bonus_list_bonuses', v_debatle_person_bonuses));
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               v_debatle_change_id, 
                                               to_jsonb(v_changes));
  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_debatle_change_person(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_change_person(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_debatle_code text := json.get_string(in_params, 'debatle_code');
  v_edited_person text := json.get_string_opt(in_params, 'edited_person', '~~~');
  v_debatle_id integer := data.get_object_id(v_debatle_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_title_attribute_id integer := data.get_attribute_id('title');

  v_system_debatle_person1 integer := data.get_object_id_opt(json.get_string_opt(data.get_attribute_value_for_update(v_debatle_id, 'debatle_person1'), null));
  v_system_debatle_person2 integer := data.get_object_id_opt(json.get_string_opt(data.get_attribute_value_for_update(v_debatle_id, 'debatle_person2'), null));
  v_system_debatle_judje integer := data.get_object_id_opt(json.get_string_opt(data.get_attribute_value_for_update(v_debatle_id, 'debatle_judge'), null));
  v_debatle_title text := json.get_string_opt(data.get_raw_attribute_value_for_share(v_debatle_id, v_title_attribute_id), '');

  v_content text[];

  v_temp_object_id integer;
begin
  assert in_request_id is not null;

  if v_edited_person not in ('instigator', 'opponent', 'judge') then
    perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Ошибка', 
      'Непонятно, какую из персон менять. Наверное что-то пошло не так. Обратитесь к мастеру.'); 
    return;
  end if;

  select array_agg(o.code order by av.value) into v_content
  from data.object_objects oo
    left join data.objects o on o.id = oo.object_id
    left join data.attribute_values av on av.object_id = o.id and av.attribute_id = v_title_attribute_id and av.value_object_id is null
  where oo.parent_object_id = data.get_object_id('player')
    and oo.object_id not in (oo.parent_object_id, coalesce(v_system_debatle_person1, -1), coalesce(v_system_debatle_person2, -1), coalesce(v_system_debatle_judje, -1));
  if v_content is null then
    v_content := array[]::text[];
  end if;

  -- создаём темповый список персон
  v_temp_object_id := data.create_object(
  null,
  jsonb_build_array(
    jsonb_build_object('code', 'title', 'value', 'Изменение дебатла "' || v_debatle_title || '"'),
    jsonb_build_object('code', 'is_visible', 'value', true, 'value_object_id', v_actor_id),
    jsonb_build_object('code', 'debatle_temp_person_list_edited_person', 'value', v_edited_person),
    jsonb_build_object('code', 'content', 'value', v_content),
    jsonb_build_object('code', 'system_debatle_temp_person_list_debatle_id', 'value', v_debatle_id)
  ),
  'debatle_temp_person_list');

  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, data.get_object_code(v_temp_object_id));
end;
$$
language plpgsql;

-- drop function pallas_project.act_debatle_change_status(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_change_status(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_debatle_code text := json.get_string(in_params, 'debatle_code');
  v_new_status text := json.get_string(in_params, 'new_status');
  v_debatle_id integer := data.get_object_id(v_debatle_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_actor_code text :=data.get_object_code(v_actor_id);

  v_is_master boolean := pp_utils.is_in_group(v_actor_id, 'master');
  v_master_group_id integer:= data.get_object_id('master'); 

  v_debatle_status text;
  v_debatle_person1 text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person1'), null);
  v_debatle_person2 text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person2'), null);
  v_debatle_judge text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_judge'), null);
  v_debatle_title text := json.get_string_opt(data.get_raw_attribute_value_for_share(v_debatle_id, 'title'), '');

  v_debatle_person1_id integer := data.get_object_id_opt(v_debatle_person1);
  v_debatle_person2_id integer := data.get_object_id_opt(v_debatle_person2);
  v_debatle_judge_id integer := data.get_object_id_opt(v_debatle_judge);

  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');

  v_content text[];
  v_new_content text[];
  v_debatles_new_id integer := data.get_object_id('debatles_new');
  v_debatles_future_id integer := data.get_object_id('debatles_future');
  v_debatles_current_id integer := data.get_object_id('debatles_current');
  v_debatles_closed_id integer := data.get_object_id('debatles_closed');

  v_changes jsonb[];
  v_message_sent boolean;

  v_audience integer[] := pallas_project.get_groups_members(json.get_string_array_opt(data.get_attribute_value_for_share(v_debatle_id, 'system_debatle_target_audience'), array[]::text[]));
  v_person_id integer;
begin
  assert in_request_id is not null;

  v_debatle_status := json.get_string_opt(data.get_attribute_value_for_update(v_debatle_id, 'debatle_status'), '~~~');

  if v_new_status = 'new' and v_debatle_status = 'draft' and (v_is_master or v_actor_code = v_debatle_person1) then
    -- добавляем в неподтверждённые
    perform pp_utils.list_prepend_and_notify(v_debatles_new_id, v_debatle_code, null, v_actor_id);
    -- Отправляем мастерам в чат уведомление 
    perform pallas_project.send_to_master_chat('Создан новый дебатл', v_debatle_code);

  elsif v_new_status = 'future' and v_debatle_status = 'new' and v_is_master then
    if v_debatle_person1 is null or v_debatle_person2 is null then
      perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Зачинщик и оппонент дебатла должны быть заполнены');
      return;
    end if;
    -- удаляем из неподтверждённых, добавляем в будущие
    perform pp_utils.list_remove_and_notify(v_debatles_new_id, v_debatle_code, null);
    perform pp_utils.list_prepend_and_notify(v_debatles_future_id, v_debatle_code, null, v_actor_id);
    -- Рассылаем уведомления
    for v_person_id in (select * from unnest(v_audience)
                        where unnest not in (coalesce(v_debatle_person1_id, -1), coalesce(v_debatle_person2_id, -1), coalesce(v_debatle_judge_id, -1))) loop
      perform pp_utils.add_notification(v_person_id, 'Вы приглашены на дебатл ' || v_debatle_title|| '. Найдите его в разделе будущих дебатлов чтобы узнать подробности и обсудить событие', v_debatle_id);
    end loop;
    if v_debatle_person1_id is not null then
      perform pp_utils.add_notification(v_debatle_person1_id, 'Вы приглашены на дебатл ' || v_debatle_title|| ' в качестве зачинщика. Дебатлы, в которых вы участвуете, находятся в разделе Мои дебатлы', v_debatle_id);
    end if;
    if v_debatle_person2_id is not null then
      perform pp_utils.add_notification(v_debatle_person2_id, 'Вы приглашены на дебатл ' || v_debatle_title|| ' в качестве оппонента. Дебатлы, в которых вы участвуете, находятся в разделе Мои дебатлы', v_debatle_id);
    end if;
    if v_debatle_judge_id is not null then
      perform pp_utils.add_notification(v_debatle_judge_id, 'Вы приглашены на дебатл ' || v_debatle_title|| ' в качестве судьи. Дебатлы, в которых вы участвуете, находятся в разделе Мои дебатлы', v_debatle_id);
    end if;

  elsif v_new_status = 'vote' and v_debatle_status = 'future' and (v_is_master or v_debatle_judge = v_actor_code) then
    if v_debatle_judge is null or v_debatle_person1 is null or v_debatle_person2 is null then
      perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Попросите мастера внести недостающих участников дебатла прежде чем начать');
      return;
    end if;
  -- удаляем из будущих, добавляем в текущие
    perform pp_utils.list_remove_and_notify(v_debatles_future_id, v_debatle_code, null);
    perform pp_utils.list_prepend_and_notify(v_debatles_current_id, v_debatle_code, null, v_actor_id);

  elsif v_new_status = 'vote_over' and v_debatle_status = 'vote' and (v_is_master or v_debatle_judge = v_actor_code) then
    null; -- не надо переставлять ничего по группам

  elsif v_new_status = 'closed' and v_debatle_status = 'vote_over' and (v_is_master or v_debatle_judge = v_actor_code) then
    -- удаляем из текущих, добавляем в завершённые
    perform pp_utils.list_remove_and_notify(v_debatles_current_id, v_debatle_code, null);
    perform pp_utils.list_prepend_and_notify(v_debatles_closed_id, v_debatle_code, null, v_actor_id);
  -- TODO тут возможно надо ещё менять какие-то статусы участникам дебатла

  elsif v_new_status = 'deleted' and (v_is_master or v_debatle_judge = v_actor_code) then
    -- удаляем
    -- из неподтверждённых
    -- из будущих
    -- из текущих
    -- из закрытых
    if v_debatle_status = 'new' then
      perform pp_utils.list_remove_and_notify(v_debatles_new_id, v_debatle_code, null);
    elsif v_debatle_status = 'future' then
      perform pp_utils.list_remove_and_notify(v_debatles_future_id, v_debatle_code, null);
    elsif v_debatle_status in ('vote', 'vote_over') then
      perform pp_utils.list_remove_and_notify(v_debatles_current_id, v_debatle_code, null);
    elsif v_debatle_status = 'closed' then
      perform pp_utils.list_remove_and_notify(v_debatles_closed_id, v_debatle_code, null);
    end if;

    -- Рассылаем уведомления    
    if v_debatle_status in ('future', 'vote') then
      for v_person_id in (select * from unnest(v_audience)
                          where unnest not in (coalesce(v_debatle_person1_id, -1), coalesce(v_debatle_person2_id, -1), coalesce(v_debatle_judge_id, -1))) loop
        perform pp_utils.add_notification(v_person_id, 'Дебатл ' || v_debatle_title|| ' был отменён');
      end loop;
      if v_debatle_person1_id is not null then
        perform pp_utils.add_notification(v_debatle_person1_id, 'Дебатл ' || v_debatle_title|| ' был отменён');
      end if;
      if v_debatle_person2_id is not null then
        perform pp_utils.add_notification(v_debatle_person2_id, 'Дебатл ' || v_debatle_title|| ' был отменён');
      end if;
      if v_debatle_judge_id is not null then
        perform pp_utils.add_notification(v_debatle_judge_id, 'Дебатл ' || v_debatle_title|| ' был отменён');
      end if;
    end if;

  else
     perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Ошибка',
      'Некорректное изменение статуса дебатла'); 
    return;
  end if;

  perform * from data.objects where id = v_debatle_id for update;

  -- если статус поменялся на future, то надо добавить видимость второму участнику, судье и аудитории, плюс создать чатик
  if v_new_status = 'future' then
    if v_debatle_person2 is not null then 
     v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', jsonb 'true', data.get_object_id(v_debatle_person2)));
    end if;
    if v_debatle_judge is not null then 
     v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', jsonb 'true', data.get_object_id(v_debatle_judge)));
    end if;
    v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', jsonb 'true', v_debatle_id));
    perform pallas_project.create_chat(v_debatle_code || '_chat',
                   jsonb_build_object(
                   'content', jsonb '[]',
                   'title', 'Обсуждение дебатла ' || json.get_string_opt(data.get_raw_attribute_value_for_share(v_debatle_id, 'title'), ''),
                   'system_chat_is_renamed', true,
                   'system_chat_parent_list', 'chats',
                   'system_chat_can_invite', false,
                   'system_chat_can_rename', false,
                   'system_chat_length', 0
                 ));
  end if;
  v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_status', to_jsonb(v_new_status)));
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               v_debatle_id, 
                                               to_jsonb(v_changes));
  if not v_message_sent then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_debatle_change_subtitle(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_change_subtitle(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_subtitle text := json.get_string_opt(in_user_params, 'subtitle','');
  v_debatle_code text := json.get_string(in_params, 'debatle_code');
  v_debatle_id  integer := data.get_object_id(v_debatle_code);
  v_actor_id  integer := data.get_active_actor_id(in_client_id);

  v_message_sent boolean := false;
  v_subtitle_attribute_id integer := data.get_attribute_id('subtitle');
begin
  assert in_request_id is not null;

  if coalesce(data.get_raw_attribute_value_for_update(v_debatle_id, v_subtitle_attribute_id), jsonb '"~~~"') <> to_jsonb(v_subtitle) then
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_debatle_id, 
                                                 jsonb_build_array(data.attribute_change2jsonb(v_subtitle_attribute_id, to_jsonb(v_subtitle))));
  end if;
  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_debatle_change_theme(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_change_theme(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_title text := json.get_string_opt(in_user_params, 'title','');
  v_debatle_code text := json.get_string(in_params, 'debatle_code');
  v_debatle_id  integer := data.get_object_id(v_debatle_code);
  v_debatle_status text := json.get_string(data.get_attribute_value(v_debatle_id,'debatle_status'));
  v_debatle_person1 text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person1'), null);

  v_actor_id  integer := data.get_active_actor_id(in_client_id);
  v_is_master boolean := pp_utils.is_in_group(v_actor_id, 'master');
  v_message_sent boolean := false;

  v_title_attribute_id integer := data.get_attribute_id('title');
begin
  assert in_request_id is not null;

  if not v_is_master and (v_debatle_status <> 'draft' or v_debatle_person1 <> data.get_object_code(v_actor_id)) then
    perform api_utils.create_show_message_actrion_notification(
      in_client_id,
      in_request_id,
      'Ошибка', 
      'Тему дебатла нельзя изменить на этом этапе'); 
    return;
  end if;

  if coalesce(data.get_raw_attribute_value_for_update(v_debatle_id, v_title_attribute_id), jsonb '"~~~"') <> to_jsonb(v_title) then
    v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_debatle_id, 
                                                 jsonb_build_array(data.attribute_change2jsonb(v_title_attribute_id, to_jsonb(v_title))));
  end if;
  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_debatle_create(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_create(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_title text := json.get_string(in_user_params, 'title');
  v_debatle_code text;
  v_debatle_id  integer;
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_debatles_all_id integer := data.get_object_id('debatles_all');
  v_debatles_my_id integer := data.get_object_id('debatles_my');

  v_master_group_id integer := data.get_object_id('master');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
begin
  assert in_request_id is not null;
  -- создаём новый дебатл

 v_debatle_id := data.create_object(
  null,
  jsonb_build_array(
    jsonb_build_object('code', 'title', 'value', v_title),
    jsonb_build_object('code', 'debatle_status', 'value', 'draft'),
    jsonb_build_object('code', 'debatle_person1', 'value', to_jsonb(data.get_object_code(v_actor_id)))
  ),
  'debatle');

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatle_id, v_is_visible_attribute_id, jsonb 'true', v_debatle_id);

  perform data.add_object_to_object(v_actor_id, v_debatle_id);

  v_debatle_code := data.get_object_code(v_debatle_id);

  perform data.create_object(
  v_debatle_code || '_target_audience',
  jsonb_build_array(
    jsonb_build_object('code', 'is_visible', 'value', true, 'value_object_id', v_debatle_id)
  ),
  'debatle_target_audience');

  -- Добавляем дебатл в список всех и в список моих для того, кто создаёт
  perform pp_utils.list_prepend_and_notify(v_debatles_all_id, v_debatle_code, v_master_group_id, v_actor_id);
  perform pp_utils.list_prepend_and_notify(v_debatles_my_id, v_debatle_code, v_actor_id, v_actor_id);

  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_debatle_code);
end;
$$
language plpgsql;

-- drop function pallas_project.act_debatle_vote(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_vote(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_debatle_code text := json.get_string(in_params, 'debatle_code');
  v_voted_person text := json.get_string_opt(in_params, 'voted_person', '~~~');
  v_debatle_id  integer := data.get_object_id(v_debatle_code);
  v_actor_id  integer := data.get_active_actor_id(in_client_id);

  v_debatle_status text := json.get_string(data.get_attribute_value_for_share(v_debatle_id,'debatle_status'));
  v_system_debatle_person1_my_vote integer;
  v_system_debatle_person2_my_vote integer;
  v_system_debatle_person1_votes integer;
  v_system_debatle_person2_votes integer;
  v_person1_my_vote_new integer;
  v_person2_my_vote_new integer;
  v_person1_votes_new integer;
  v_person2_votes_new integer;
  v_nothing_changed boolean := false;

  v_changes jsonb[];

  v_is_master boolean := pp_util.is_in_group(v_actor_id, 'master');
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;

  if v_debatle_status <> 'vote' then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Не время для голосования');
    return;
  end if;

  if v_voted_person not in ('instigator', 'opponent') then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Непонятно за кого проголосовали. Наверное что-то пошло не так. Обратитесь к мастеру.');
    return;
  end if;

  perform * from data.objects o where o.id = v_debatle_id for update;

  v_system_debatle_person1_my_vote := json.get_integer_opt(data.get_raw_attribute_value_for_update(v_debatle_id, 'system_debatle_person1_my_vote', v_actor_id), 0);
  v_system_debatle_person2_my_vote := json.get_integer_opt(data.get_raw_attribute_value_for_update(v_debatle_id, 'system_debatle_person2_my_vote', v_actor_id), 0);

  assert v_system_debatle_person1_my_vote >= 0;
  assert v_system_debatle_person2_my_vote >= 0;

  if v_voted_person = 'instigator' then 
    if v_system_debatle_person1_my_vote > 0 then 
      v_nothing_changed := true;
    else
      v_person1_my_vote_new := 1;
      v_person2_my_vote_new := 0;
    end if;
  elsif v_voted_person = 'opponent' then 
    if v_system_debatle_person2_my_vote > 0 then 
      v_nothing_changed := true;
    else
      v_person2_my_vote_new := 1;
      v_person1_my_vote_new := 0;
    end if;
  end if;

  if not v_nothing_changed then
    v_system_debatle_person1_votes := json.get_integer_opt(data.get_attribute_value_for_update(v_debatle_id, 'system_debatle_person1_votes'), 0);
    v_system_debatle_person2_votes := json.get_integer_opt(data.get_attribute_value_for_update(v_debatle_id, 'system_debatle_person2_votes'), 0);
    v_person1_votes_new := v_system_debatle_person1_votes + v_person1_my_vote_new - v_system_debatle_person1_my_vote;
    v_person2_votes_new := v_system_debatle_person2_votes + v_person2_my_vote_new - v_system_debatle_person2_my_vote;

    if v_system_debatle_person1_my_vote <> v_person1_my_vote_new then 
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person1_my_vote', to_jsonb(v_person1_my_vote_new), v_actor_id));
    end if;
    if v_system_debatle_person2_my_vote <> v_person2_my_vote_new then 
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person2_my_vote', to_jsonb(v_person2_my_vote_new), v_actor_id));
    end if;
    if v_system_debatle_person1_votes <> v_person1_votes_new then 
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person1_votes', to_jsonb(v_person1_votes_new)));
    end if;
    if v_system_debatle_person2_votes <> v_person2_votes_new then 
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person2_votes', to_jsonb(v_person2_votes_new)));
    end if;
    if array_length(v_changes, 1) > 0 then
      v_message_sent := data.change_current_object(in_client_id, 
                                                   in_request_id,
                                                   v_debatle_id, 
                                                   to_jsonb(v_changes));
    end if;
  end if;

  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_document_add_to_my(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_add_to_my(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_document_id integer := data.get_object_id(v_document_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_document_category text := json.get_string_opt(data.get_attribute_value_for_share(v_document_id, 'document_category'),'~');
  v_my_documents_id integer := data.get_object_id('my_documents');
  v_official_documents_id integer := data.get_object_id('official_documents');
  v_rules_documents_id integer := data.get_object_id('rules_documents');
  v_system_document_is_my boolean := json.get_boolean_opt(data.get_raw_attribute_value_for_update(v_document_id, 'system_document_is_my', v_actor_id), false);
  v_message_sent boolean;
begin
  assert in_request_id is not null;
  assert not v_system_document_is_my;

  case v_document_category
  when 'private' then 
    perform pp_utils.list_prepend_and_notify(v_my_documents_id, v_document_code, v_actor_id);
  when 'official' then
    perform pp_utils.list_prepend_and_notify(v_official_documents_id, v_document_code, v_actor_id);
  when 'rule' then
    perform pp_utils.list_prepend_and_notify(v_rules_documents_id, v_document_code, v_actor_id);
  else
    null;
  end case;

  v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_document_id, 
                                               jsonb_build_array(data.attribute_change2jsonb('system_document_is_my', jsonb 'true', v_actor_id)));

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;

  perform api_utils.create_ok_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;

-- drop function pallas_project.act_document_back_to_editing(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_back_to_editing(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_document_id integer := data.get_object_id(v_document_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_system_document_participants jsonb;
  v_document_participants text;
  v_document_status text;
  v_person_code text;

  v_message text := 'Документ возвращён на редактирование';

  v_document_content text[];
  v_changes jsonb[];
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;

  v_document_status := json.get_string_opt(data.get_attribute_value_for_update(v_document_id, 'document_status'),'');
  assert v_document_status = 'signing';

  v_system_document_participants := data.get_attribute_value_for_update(v_document_id, 'system_document_participants');
  -- Отзываем все подписи
  for v_person_code in (select x.key
                          from jsonb_each_text(v_system_document_participants) x
                          where x.value = 'true') loop
    v_system_document_participants := jsonb_set(v_system_document_participants, array[v_person_code], jsonb 'false');
  end loop;

  v_document_participants := pallas_project.get_document_participants(v_system_document_participants, v_actor_id, true);

  v_changes := array[]::jsonb[];

  select array_agg(x.key) into v_document_content
    from jsonb_each_text(v_system_document_participants) x;

  v_changes := array_append(v_changes, data.attribute_change2jsonb('document_status', jsonb '"draft"'));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('system_document_participants', v_system_document_participants));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('document_participants', to_jsonb(v_document_participants)));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('content', to_jsonb(v_document_content), v_document_code || '_signers_list'));
  v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_document_id, 
                                               to_jsonb(v_changes));

  for v_person_code in (select x.key
                          from jsonb_each_text(v_system_document_participants) x
                          where x.value = 'false') loop
    perform pp_utils.add_notification(data.get_object_id(v_person_code), v_message, v_document_id);
  end loop;

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_document_create(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_create(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_title text := json.get_string_opt(in_user_params, 'title', null);
  v_document_code text;
  v_document_id integer;

  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_my_documents_id integer := data.get_object_id('my_documents');
  v_master_group_id integer := data.get_object_id('master');
begin
  assert in_request_id is not null;

  -- Создаём документ
  v_document_id := data.create_object(
  null,
    jsonb_build_array(
      jsonb_build_object('code', 'title', 'value', v_document_title),
      jsonb_build_object('code', 'document_category', 'value', 'private'),
      jsonb_build_object('code', 'system_document_author', 'value', v_actor_id),
      jsonb_build_object('code', 'document_author', 'value', json.get_string(data.get_attribute_value(v_actor_id, 'title')) , 'value_object_id', v_master_group_id),
      jsonb_build_object('code', 'document_last_edit_time', 'value', to_char(clock_timestamp(),'DD.MM.YYYY hh24:mi:ss'), 'value_object_id', v_master_group_id),
      jsonb_build_object('code', 'document_last_edit_time', 'value', to_char(clock_timestamp(),'DD.MM.YYYY hh24:mi:ss'), 'value_object_id', v_actor_id),
      jsonb_build_object('code', 'system_document_is_my', 'value', true, 'value_object_id', v_actor_id)
    ),
  'document');

  v_document_code := data.get_object_code(v_document_id);

  if not pp_utils.is_in_group(v_actor_id, 'master') then
    perform pp_utils.list_prepend_and_notify(v_my_documents_id, v_document_code, v_actor_id);
  end if;
  perform pp_utils.list_prepend_and_notify(v_my_documents_id, v_document_code, v_master_group_id);

  -- Заходим в документ
  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_document_code);
end;
$$
language plpgsql;

-- drop function pallas_project.act_document_delete(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_delete(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_document_id integer := data.get_object_id(v_document_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_master_group_id integer := data.get_object_id('master');

  v_document_author integer;

  v_changes jsonb[];
begin
  assert in_request_id is not null;

  v_document_author := json.get_integer(data.get_attribute_value(v_document_id, 'system_document_author'));
  v_changes := array[]::jsonb[];

  v_changes := array_append(v_changes, data.attribute_change2jsonb('document_status', jsonb '"deleted"'));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', to_jsonb(false), null));

  perform data.change_object_and_notify(v_document_id, 
                                        to_jsonb(v_changes),
                                        v_actor_id);

  perform api_utils.create_go_back_action_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;

-- drop function pallas_project.act_document_delete_signer(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_delete_signer(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_list_code text := json.get_string(in_params, 'list_code');
  v_document_id integer := data.get_object_id(v_document_code);
  v_document_signers_list_id integer := data.get_object_id(v_document_code || '_signers_list');
  v_actor_id integer :=data.get_active_actor_id(in_client_id);

  v_system_document_participants jsonb;
  v_document_participants text;
  v_document_signers_list_participants text;
  v_document_status text;
  v_person_code text;

  v_document_content text[];
  v_content text[];
  v_changes jsonb[];
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;

  v_document_status := json.get_string_opt(data.get_attribute_value_for_share(v_document_id, 'document_status'),'');
  assert v_document_status = 'draft';

  v_system_document_participants := data.get_attribute_value_for_update(v_document_id, 'system_document_participants');
  v_system_document_participants := v_system_document_participants - v_list_code;

  v_document_participants := pallas_project.get_document_participants(v_system_document_participants, v_actor_id, true);

  v_changes := array[]::jsonb[];

  select array_agg(x.key) into v_document_content
    from jsonb_each_text(v_system_document_participants) x;

  v_changes := array_append(v_changes, data.attribute_change2jsonb('system_document_participants', v_system_document_participants));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('document_participants', to_jsonb(v_document_participants)));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('content', to_jsonb(v_document_content), v_document_code || '_signers_list'));
  v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_document_id, 
                                               to_jsonb(v_changes));

  v_document_signers_list_participants := pallas_project.get_document_participants(v_system_document_participants, v_actor_id);
  v_content := pallas_project.get_document_possible_signers(v_document_id);

  perform data.change_object_and_notify(v_document_signers_list_id, 
                                        jsonb_build_array(
                                          data.attribute_change2jsonb('document_signers_list_participants', to_jsonb(v_document_signers_list_participants)),
                                          data.attribute_change2jsonb('content', to_jsonb(v_content))
                                        ),
                                        v_actor_id);

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_document_edit(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_edit(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_title text := json.get_string(in_user_params, 'title');
  v_document_text text := json.get_string(in_user_params, 'document_text');
  v_document_id integer := data.get_object_id(v_document_code);
  v_document_signers_list_id integer;
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_changes jsonb[];
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;

  v_changes := array[]::jsonb[];

  v_changes := array_append(v_changes, data.attribute_change2jsonb('title', to_jsonb(v_title)));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('document_text', to_jsonb(v_document_text)));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('document_last_edit_time', to_jsonb(to_char(clock_timestamp(),'DD.MM.YYYY hh24:mi:ss')), v_actor_id));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('document_last_edit_time', to_jsonb(to_char(clock_timestamp(),'DD.MM.YYYY hh24:mi:ss')), 'master'));
  v_message_sent := data.change_current_object(in_client_id, 
                                                 in_request_id,
                                                 v_document_id, 
                                                 to_jsonb(v_changes));

  if data.is_object_exists(v_document_code || '_signers_list') then
    v_document_signers_list_id := data.get_object_id(v_document_code || '_signers_list');
    perform data.change_object_and_notify(v_document_signers_list_id, 
                                        jsonb_build_array(
                                          data.attribute_change2jsonb('title', to_jsonb('Добавление участников документа ' || v_title))
                                        ),
                                        v_actor_id);
  end if;

  if not v_message_sent then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_document_make_official(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_make_official(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_document_id integer := data.get_object_id(v_document_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_document_category text := json.get_string_opt(data.get_attribute_value_for_update(v_document_id, 'document_category'),'~');
  v_system_document_author integer := json.get_integer(data.get_attribute_value(v_document_id, 'system_document_author'));
  v_my_documents_id integer := data.get_object_id('my_documents');
  v_official_documents_id integer := data.get_object_id('official_documents');
  v_person_id integer;
  v_master_group_id integer := data.get_object_id('master');
  v_message_sent boolean;

  v_list_attributes jsonb;
  v_document_title text := json.get_string_opt(data.get_raw_attribute_value_for_share(v_document_id, 'title'),'');
  v_content text[];
  v_signer_list_id integer;
begin
  assert in_request_id is not null;
  assert v_document_category = 'private';

  for v_person_id in select * from unnest(pallas_project.get_group_members('all_person')) loop
    v_content := json.get_string_array_opt(data.get_raw_attribute_value_for_share(v_my_documents_id, 'content', v_person_id), array[]::text[]);
    if array_position(v_content, v_document_code) is not null then
      perform pp_utils.list_remove_and_notify(v_my_documents_id, v_document_code, v_person_id);
      perform pp_utils.list_prepend_and_notify(v_official_documents_id, v_document_code, v_person_id);
    end if;
  end loop;
  perform pp_utils.list_remove_and_notify(v_my_documents_id, v_document_code, v_master_group_id);
  perform pp_utils.list_prepend_and_notify(v_official_documents_id, v_document_code, v_master_group_id);

  v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_document_id, 
                                               jsonb_build_array(data.attribute_change2jsonb('document_category', jsonb '"official"'),
                                                                 data.attribute_change2jsonb('document_status', jsonb '"draft"')));

  -- Создаём объект для изменения списка участников документа
  if not data.is_object_exists(v_document_code || '_signers_list') then
    v_content:= pallas_project.get_document_possible_signers(v_document_id);
    v_list_attributes := jsonb_build_array(
      jsonb_build_object('code', 'title', 'value', 'Добавление участников документа ' || v_document_title),
      jsonb_build_object('code', 'is_visible', 'value', true, 'value_object_id', v_system_document_author),
      jsonb_build_object('code', 'document_signers_list_participants', 'value', ''),
      jsonb_build_object('code', 'content', 'value', v_content)
    );
    v_signer_list_id := data.create_object(v_document_code || '_signers_list', v_list_attributes, 'document_signers_list');
    perform data.add_object_to_object(v_system_document_author, v_signer_list_id);
    perform data.add_object_to_object(data.get_object_id('master'), v_signer_list_id);
  end if;

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_document_make_rule(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_make_rule(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_document_id integer := data.get_object_id(v_document_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_document_category text := json.get_string_opt(data.get_attribute_value_for_update(v_document_id, 'system_document_category'),'~');
  v_my_documents_id integer := data.get_object_id('my_documents');
  v_rules_documents_id integer := data.get_object_id('rules_documents');
  v_person_id integer;
  v_master_group_id integer := data.get_object_id('master');
  v_message_sent boolean;

  v_content text[];
begin
  assert in_request_id is not null;
  assert v_document_category = 'private';

  for v_person_id in select * from unnest(pallas_project.get_group_members('all_person')) loop
    v_content := json.get_string_array_opt(data.get_raw_attribute_value_for_share(v_my_documents_id, 'content', v_person_id), array[]::text[]);
    if array_position(v_content, v_document_code) is not null then
      perform pp_utils.list_remove_and_notify(v_my_documents_id, v_document_code, v_person_id);
      perform pp_utils.list_prepend_and_notify(v_rules_documents_id, v_document_code, v_person_id);
    end if;
  end loop;
  perform pp_utils.list_remove_and_notify(v_my_documents_id, v_document_code, v_master_group_id);
  perform pp_utils.list_prepend_and_notify(v_rules_documents_id, v_document_code, v_master_group_id);

  v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_document_id, 
                                               jsonb_build_array(data.attribute_change2jsonb('document_category', jsonb '"rule"')));

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_document_send_to_sign(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_send_to_sign(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_document_id integer := data.get_object_id(v_document_code);
  v_actor_id integer :=data.get_active_actor_id(in_client_id);

  v_system_document_participants jsonb;
  v_person_code text;
  v_unsined_count integer;

  v_message text := 'Вам на подпись пришёл документ';

  v_changes jsonb[];
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;

  v_system_document_participants := data.get_attribute_value_for_share(v_document_id, 'system_document_participants');

  v_changes := array[]::jsonb[];

  v_changes := array_append(v_changes, data.attribute_change2jsonb('content', null, v_document_code || '_signers_list'));

-- Считаем, сколько осталось отсутствующих подписей. Если нисколько, меняем статус документа
  select count(1) into v_unsined_count
    from jsonb_each_text(v_system_document_participants) x 
    where x.value = 'false';
  if v_unsined_count = 0 then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('document_status', jsonb '"signed"'));
  else 
    v_changes := array_append(v_changes, data.attribute_change2jsonb('document_status', jsonb '"signing"'));
  end if;

  v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_document_id, 
                                               to_jsonb(v_changes));

  for v_person_code in (select x.key
                          from jsonb_each_text(v_system_document_participants) x
                          where x.value = 'false') loop
    perform pp_utils.add_notification(data.get_object_id(v_person_code), v_message, v_document_id, true);
  end loop;



  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_document_share(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_share(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_share_list_code text := json.get_string(in_params, 'share_list_code');
  v_share_list_id integer := data.get_object_id(v_share_list_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_document_id integer := json.get_integer(data.get_attribute_value(v_share_list_id, 'system_document_temp_list_document_id'));

  v_system_document_temp_share_list integer[] := json.get_integer_array_opt(data.get_attribute_value(v_share_list_id, 'system_document_temp_share_list'), array[]::integer[]);

  v_person_id integer;
  v_message text := 'Пользователь "' || json.get_string(data.get_attribute_value(v_actor_id, 'title')) || '" поделился с вами документом';
begin
  assert in_request_id is not null;

  for v_person_id in (select * from unnest(v_system_document_temp_share_list)) loop
    perform pp_utils.add_notification(v_person_id, v_message, v_document_id, true);
  end loop;

  perform api_utils.create_go_back_action_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;

-- drop function pallas_project.act_document_share_list(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_share_list(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_document_id integer := data.get_object_id(v_document_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_system_document_temp_list_document_id_attribute_id integer := data.get_attribute_id('system_document_temp_list_document_id');

  v_document_title text := json.get_string_opt(data.get_raw_attribute_value_for_share(v_document_id, v_title_attribute_id), '');
  v_is_master boolean := pp_utils.is_in_group(in_client_id, 'master');
  v_persons text := '';
  v_name record;

  v_content text[];

  v_temp_object_code text;
  v_temp_object_id integer;

  v_player_id integer:= data.get_object_id('player');
begin
  assert in_request_id is not null;

  -- Собираем список всех персонажей кроме себя
  select array_agg(o.code order by av.value) into v_content
  from data.object_objects oo
    left join data.objects o on o.id = oo.object_id
    left join data.attribute_values av on av.object_id = o.id and av.attribute_id = v_title_attribute_id and av.value_object_id is null
  where oo.parent_object_id = v_player_id
    and oo.object_id not in (oo.parent_object_id, v_actor_id);

  if v_content is null then
     v_content := array[]::integer[];
  end if;

-- создаём темповый список персон
  v_temp_object_id := data.create_object(
  null,
    jsonb_build_array(
      jsonb_build_object('code', 'title', 'value', format('Поделиться документом %s', v_document_title)),
      jsonb_build_object('code', 'is_visible', 'value', true, 'value_object_id', v_actor_id),
      jsonb_build_object('code', 'system_document_temp_list_document_id', 'value', v_document_id),
      jsonb_build_object('code', 'system_document_temp_share_list', 'value', array[]::text[]),
      jsonb_build_object('code', 'document_temp_share_list', 'value', ''),
      jsonb_build_object('code', 'content', 'value', v_content)
    ),
  'document_temp_share_list');

  v_temp_object_code := data.get_object_code(v_temp_object_id);

  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_temp_object_code);
end;
$$
language plpgsql;

-- drop function pallas_project.act_document_sign(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_sign(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_document_id integer := data.get_object_id(v_document_code);
  v_actor_id integer :=data.get_active_actor_id(in_client_id);
  v_actor_code text := data.get_object_code(v_actor_id);

  v_system_document_participants jsonb;
  v_document_participants text;
  v_person_code text;

  v_unsined_count integer;
  v_message text := 'Документ подписан всеми участниками';

  v_changes jsonb[];
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;

  v_system_document_participants := data.get_attribute_value_for_update(v_document_id, 'system_document_participants');

  v_changes := array[]::jsonb[];

  -- Сохраняем подпись, меняем список учасников
  v_system_document_participants := jsonb_set(v_system_document_participants, array[v_actor_code], jsonb 'true');
  v_document_participants := pallas_project.get_document_participants(v_system_document_participants, v_actor_id, true);

  v_changes := array_append(v_changes, data.attribute_change2jsonb('system_document_participants', v_system_document_participants));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('document_participants', to_jsonb(v_document_participants)));

  -- Считаем, сколько осталось отсутствующих подписей. Если нисколько, меняем статус документа и шлём всем уведомления
  select count(1) into v_unsined_count
    from jsonb_each_text(v_system_document_participants) x 
    where x.value = 'false';
  if v_unsined_count = 0 then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('document_status', jsonb '"signed"'));
    for v_person_code in (select x.key
                          from jsonb_each_text(v_system_document_participants) x) loop
      perform pp_utils.add_notification(data.get_object_id(v_person_code), v_message, v_document_id);
    end loop;
    perform pallas_project.send_to_master_chat(v_message, v_document_code);
  end if;

  v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_document_id, 
                                               to_jsonb(v_changes));

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_document_sign_for_signer(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_sign_for_signer(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_list_code text := json.get_string(in_params, 'list_code');
  v_document_id integer := data.get_object_id(v_document_code);
  v_document_signers_list_id integer := data.get_object_id(v_document_code || '_signers_list');
  v_actor_id integer :=data.get_active_actor_id(in_client_id);

  v_system_document_participants jsonb;
  v_document_participants text;
  v_document_signers_list_participants text;
  v_document_status text;
  v_person_code text;

  v_document_content text[];
  v_content text[];
  v_changes jsonb[];
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;

  v_document_status := json.get_string_opt(data.get_attribute_value_for_share(v_document_id, 'document_status'),'');
  assert v_document_status = 'draft';

  v_system_document_participants := data.get_attribute_value_for_update(v_document_id, 'system_document_participants');
  v_system_document_participants := jsonb_set(v_system_document_participants, array[v_list_code], jsonb 'true');

  v_document_participants := pallas_project.get_document_participants(v_system_document_participants, v_actor_id, true);

  v_changes := array[]::jsonb[];

  v_changes := array_append(v_changes, data.attribute_change2jsonb('system_document_participants', v_system_document_participants));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('document_participants', to_jsonb(v_document_participants)));
  v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_document_id, 
                                               to_jsonb(v_changes));

  if not v_message_sent then
   perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_finish_lottery(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_finish_lottery(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_lottery_id integer := data.get_object_id('lottery');
  v_lottery_status text := json.get_string(data.get_attribute_value_for_update(v_lottery_id, 'lottery_status'));
  v_menu_attr integer := json.get_integer(data.get_attribute_value_for_update('menu', 'force_object_diff'));
  v_lottery_owner text := json.get_string_opt(data.get_attribute_value_for_share(v_lottery_id, 'system_lottery_owner'), null);
  v_total_ticket_count integer;
  v_win_ticket_num integer;
  v_current_ticket_num integer := 0;
  v_aster record;
  v_aster_id integer;
  v_text text;
  v_player_id integer;
  v_notified boolean;
begin
  assert in_request_id is not null;
  assert pp_utils.is_in_group(v_actor_id, 'master') or v_actor_id = data.get_object_id(v_lottery_owner);

  if v_lottery_status = 'active' then
    -- Ищем победителя
    select sum(ticket_count)
    into v_total_ticket_count
    from
    (
      select json.get_integer(value) ticket_count
      from data.attribute_values
      where
        object_id = v_lottery_id and
        attribute_id = data.get_attribute_id('lottery_ticket_count') and
        value_object_id is not null
      for share
    ) a;

    v_win_ticket_num := random.random_integer(1, v_total_ticket_count);

    for v_aster in
    (
      select value_object_id, json.get_integer(value) ticket_count
      from data.attribute_values
      where
        object_id = v_lottery_id and
        attribute_id = data.get_attribute_id('lottery_ticket_count') and
        value_object_id is not null
    )
    loop
      v_current_ticket_num := v_current_ticket_num + v_aster.ticket_count;
      if v_current_ticket_num >= v_win_ticket_num then
        v_aster_id := v_aster.value_object_id;
        exit;
      end if;
    end loop;

    v_text := 'Лотерея завершена. Победитель: ' || pp_utils.link(v_aster_id);

    -- Отправляем уведомление игрокам
    for v_player_id in
    (
      select object_id
      from data.object_objects
      where
        parent_object_id = data.get_object_id('player') and
        object_id != parent_object_id and
        object_id != v_aster_id
    )
    loop
      perform pp_utils.add_notification(v_player_id, v_text, v_lottery_id, true);
    end loop;

    -- Отправляем уведомление победителю
    perform pp_utils.add_notification(v_aster_id, 'Поздравляем, вы выиграли в лотерее и получаете гражданство ООН!', v_lottery_id, true);

    -- Меняем экономику на гражданина
    perform pallas_project.change_aster_to_un(v_aster_id, v_actor_id);

    -- Завершаем лотерею
    v_notified :=
      data.change_current_object(
        in_client_id,
        in_request_id,
        v_lottery_id,
        format('{"lottery_status": "finished", "lottery_winner": "%s"}', data.get_object_code(v_aster_id))::jsonb,
        'Finish lottery action');
    assert v_notified;
    perform data.change_object_and_notify(
      data.get_object_id('menu'),
      jsonb_build_object('force_object_diff', v_menu_attr + 1),
      v_actor_id,
      'Finish lottery action');
    return;
  end if;

  perform api_utils.create_ok_notification(
    in_client_id,
    in_request_id);
end;
$$
language plpgsql;

-- drop function pallas_project.act_go_back(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_go_back(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
begin
  assert in_request_id is not null;

  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'action',
    '{"action": "go_back", "action_data": {}}'::jsonb);
end;
$$
language plpgsql;

-- drop function pallas_project.act_login(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_login(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_password text := json.get_string(in_user_params, 'password');
  v_login_id integer;

begin
  assert in_request_id is not null;
  assert in_user_params is not null;

  select id into v_login_id from data.logins where code = v_password;

  if v_login_id is not null then
  -- Заменим логин
    perform data.log('info', format('Set login %s for client %s (password: %s)', v_login_id, in_client_id, v_password));
    perform data.set_login(in_client_id, v_login_id);
    -- И отправим новый список акторов
    perform api_utils.process_get_actors_message(in_client_id, in_request_id);
  else
  -- Вернём ошибку, если на нашли логин в табличке
    perform data.log('warning', format('Invalid password %s (client: %s)', v_password, in_client_id));
    perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      format('{"action": "show_message", "action_data": {"title": "%s", "message": "%s"}}', 'Ошибка', 'Пароль не найден')::jsonb); 
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.act_logout(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_logout(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_login_id integer := data.get_param('default_login_id');

begin
  assert in_request_id is not null;

  if v_login_id is not null then
  -- Заменим логин
    perform data.set_login(in_client_id, v_login_id);
    -- И отправим новый список акторов
    perform api_utils.process_get_actors_message(in_client_id, in_request_id);
  else
  -- Вернём ошибку, если на нашли логин в табличке
    perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      format('{"action": "show_message", "action_data": {"title": "%s", "message": "%s"}}', 'Ошибка', 'Пароль не найден')::jsonb); 
  end if;
end;
$$
language plpgsql;

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
language plpgsql;

-- drop function pallas_project.act_remove_notification(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_remove_notification(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_notification_code text := json.get_string(in_params);
  v_notification_id integer := data.get_object_id(v_notification_code);
  v_system_person_notification_count_attr_id integer := data.get_attribute_id('system_person_notification_count');
  v_content_attr_id integer := data.get_attribute_id('content');
  v_notifications_id integer := data.get_object_id('notifications');
  v_notifications_count integer := json.get_integer(data.get_attribute_value_for_update(v_actor_id, v_system_person_notification_count_attr_id)) - 1;
  v_content text[] :=
    array_remove(
      json.get_string_array(data.get_raw_attribute_value_for_update(v_notifications_id, v_content_attr_id, v_actor_id)),
      v_notification_code);
  v_notified boolean;
begin
  perform data.set_attribute_value(v_notification_id, 'is_visible', jsonb 'false', v_actor_id);
  perform data.change_object_and_notify(
    v_actor_id,
    jsonb_build_object('system_person_notification_count', v_notifications_count),
    v_actor_id,
    'Open notification');

  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      v_notifications_id,
      jsonb '[]' || data.attribute_change2jsonb('content', to_jsonb(v_content), v_actor_id),
      'Open notification');
  assert v_notified;
end;
$$
language plpgsql;

-- drop function pallas_project.act_transfer_money(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_transfer_money(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_params);
  v_object_id integer := data.get_object_id(v_object_code);
  v_original_object_code text;
  v_sum bigint := json.get_bigint(in_user_params, 'sum');
  v_comment text := pp_utils.trim(json.get_string(in_user_params, 'comment'));
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_actor_economy_type text := json.get_string(data.get_attribute_value_for_share(v_actor_id, 'system_person_economy_type'));
  v_actor_current_sum bigint := json.get_bigint(data.get_attribute_value_for_update(v_actor_id, 'system_money'));
  v_object_economy_type text;
  v_object_current_sum bigint;
  v_tax bigint;
  v_tax_organization_id integer;
  v_tax_sum bigint;
  v_tax_coeff numeric;
  v_single_diff jsonb;
  v_notified boolean;
  v_groups integer[];
begin
  v_original_object_code := json.get_string_opt(data.get_attribute_value(v_object_id, 'system_org_synonym'), null);
  if v_original_object_code is not null then
    v_object_id := data.get_object_id(v_original_object_code);
    v_object_code := v_original_object_code;
  end if;

  assert v_actor_id != v_object_id;

  v_object_economy_type := json.get_string_opt(data.get_attribute_value_for_share(v_object_id, 'system_person_economy_type'), '');
  v_object_current_sum := json.get_bigint(data.get_attribute_value_for_update(v_object_id, 'system_money'));

  if v_comment = '' then
    v_comment := 'Перевод средств';
  else
    v_comment := E'Перевод средств\nКомментарий:\n' || v_comment;
  end if;

  if v_actor_economy_type = 'un' or v_object_economy_type = 'un' then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
    return;
  end if;

  if v_actor_current_sum < v_sum then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Не хватает денег', 'На вашем счету нет указанной суммы.');
    return;
  end if;

  if v_object_economy_type != '' then
    declare
      v_district_id integer := data.get_object_id(json.get_string(data.get_attribute_value_for_share(v_object_id, 'person_district')));
      v_district_control jsonb := data.get_attribute_value_for_share(v_district_id, 'district_control');
      v_org_tax integer;
    begin
      assert v_district_control is not null;

      if v_district_control != jsonb 'null' then
        v_tax_coeff := json.get_number(data.get_attribute_value_for_share(v_district_id, 'system_district_tax_coeff'));
        v_tax_organization_id := data.get_object_id(pallas_project.control_to_org_code(json.get_string(v_district_control)));
        v_org_tax := json.get_integer(data.get_attribute_value_for_share(v_tax_organization_id, 'system_org_tax'));
        v_tax := ceil(v_org_tax * 0.01 * v_sum);
      end if;
    end;
  end if;

  v_notified :=
    data.process_diffs_and_notify_current_object(
      pallas_project.change_money(v_actor_id, v_actor_current_sum - v_sum, v_actor_id, 'Transfer'),
      in_client_id,
      in_request_id,
      v_object_id);
  -- Как минимум поменяется max_value у действия
  assert v_notified;

  perform data.process_diffs_and_notify(
    pallas_project.change_money(v_object_id, v_object_current_sum + v_sum - coalesce(v_tax, 0), v_actor_id, 'Transfer'));

  perform pallas_project.notify_transfer_sender(v_actor_id, v_sum);
  perform pallas_project.notify_transfer_receiver(v_object_id, v_sum - coalesce(v_tax, 0));

  if v_tax_organization_id is not null and v_tax != 0 then
    assert v_tax_organization_id != v_object_id;

    -- Начисление налога на следующий цикл
    v_tax_sum := json.get_bigint(data.get_attribute_value_for_update(v_tax_organization_id, 'system_org_current_tax_sum'));
    perform data.change_object_and_notify(
      v_tax_organization_id,
      format(
      '[
        {"code": "system_org_current_tax_sum", "value": %s},
        {"code": "org_current_tax_sum", "value": %s, "value_object_code": "master"}
      ]',
      v_tax_sum + (v_tax * v_tax_coeff)::bigint,
      v_tax_sum + (v_tax * v_tax_coeff)::bigint)::jsonb,
      v_actor_id,
      'Transfer tax');
  end if;

  if v_object_economy_type != '' then
    v_groups := array[v_object_id];
  else
    v_groups :=
      array[
        data.get_object_id(v_object_code || '_head'),
        data.get_object_id(v_object_code || '_economist'),
        data.get_object_id(v_object_code || '_auditor'),
        data.get_object_id(v_object_code || '_temporary_auditor')];
  end if;

  perform pallas_project.create_transaction(
    v_actor_id,
    v_comment,
    -v_sum,
    v_actor_current_sum - v_sum,
    v_tax,
    v_object_id,
    v_actor_id,
    array[v_actor_id]);
  perform pallas_project.create_transaction(
    v_object_id,
    v_comment,
    v_sum,
    v_object_current_sum + v_sum - coalesce(v_tax, 0),
    v_tax,
    v_actor_id,
    v_actor_id,
    v_groups);
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_anonymous(integer, integer);

create or replace function pallas_project.actgenerator_anonymous(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_actions_list text := '';
begin
  assert in_actor_id is not null;

  /*v_actions_list := v_actions_list || ', "' || 'create_random_person":' || 
    '{"code": "create_random_person", "name": "Нажми меня", "disabled": false, "params": {}}';*/
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_chat(integer, integer);

create or replace function pallas_project.actgenerator_chat(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_is_master boolean;
  v_chat_code text;
  v_chat_is_mute boolean;
  v_chat_can_invite boolean;
  v_chat_can_leave boolean;
  v_chat_can_mute boolean;
  v_chat_can_rename boolean;
  v_chat_cant_write boolean;
  v_chat_cant_see_members boolean;
  v_chat_parent_list text;
begin
  assert in_actor_id is not null;

  v_is_master := pp_utils.is_in_group(in_actor_id, 'master');
  v_chat_code := data.get_object_code(in_object_id);

  v_chat_parent_list := json.get_string_opt(data.get_attribute_value(in_object_id, 'system_chat_parent_list'), '~');
  v_chat_can_invite := json.get_boolean_opt(data.get_attribute_value_for_share(in_object_id, 'system_chat_can_invite'), false);
  v_chat_can_leave := json.get_boolean_opt(data.get_attribute_value_for_share(in_object_id, 'system_chat_can_leave'), false);
  v_chat_can_mute := json.get_boolean_opt(data.get_attribute_value_for_share(in_object_id, 'system_chat_can_mute'), false);
  v_chat_can_rename := json.get_boolean_opt(data.get_attribute_value_for_share(in_object_id, 'system_chat_can_rename'), false);
  v_chat_cant_write := json.get_boolean_opt(data.get_attribute_value_for_share(in_object_id, 'system_chat_cant_write'), false);
  v_chat_cant_see_members := json.get_boolean_opt(data.get_attribute_value_for_share(in_object_id, 'system_chat_cant_see_members'), false);

  if not v_chat_cant_see_members then
    v_actions_list := v_actions_list || 
        format(', "chat_add_person": {"code": "act_open_object", "name": "%s участников", "disabled": false, '||
                '"params": {"object_code": "%s_person_list"}}',
                case when v_is_master and v_chat_parent_list <> 'master_chats' or v_chat_can_invite then 'Добавить/посмотреть'
                else 'Посмотреть' end,
                v_chat_code);
  end if;

  if pp_utils.is_in_group(in_actor_id, v_chat_code) and (v_is_master and v_chat_parent_list <> 'master_chats' or v_chat_can_leave) then
    v_actions_list := v_actions_list || 
        format(', "chat_leave": {"code": "chat_leave", "name": "Выйти из чата", "disabled": false, "warning": "Вы уверены? Этот чат исчезнет из вашего списка чатов, и вернуться вы не сможете.",'||
                '"params": {"chat_code": "%s"}}',
                v_chat_code);
  end if;

  if pp_utils.is_in_group(in_actor_id, v_chat_code) and (v_is_master and v_chat_parent_list <> 'master_chats' or v_chat_can_mute) then
    v_chat_is_mute := json.get_boolean_opt(data.get_raw_attribute_value_for_share(in_object_id, 'chat_is_mute', in_actor_id), false);
    v_actions_list := v_actions_list || 
        format(', "chat_mute": {"code": "chat_mute", "name": "%s", "disabled": false,'||
                '"params": {"chat_code": "%s", "mute_on_off": "%s"}}',
                case when v_chat_is_mute then
                  'Включить уведомления'
                else 'Отключить уведомления' end,
                v_chat_code,
                case when v_chat_is_mute then
                  'off'
                else 'on' end);
  end if;

  if (v_is_master and v_chat_parent_list <> 'master_chats') or v_chat_can_rename then
    v_actions_list := v_actions_list || 
        format(', "chat_rename": {"code": "chat_rename", "name": "Переименовать чат", "disabled": false, "warning": "Чат поменяет имя для всех его участников.",'||
                '"params": {"chat_code": "%s"}, "user_params": [{"code": "title", "description": "Введите имя чата", "type": "string", "restrictions": {"min_length": 1}, "default_value": "%s"}]}',
                v_chat_code,
                json.get_string_opt(data.get_raw_attribute_value_for_share(in_object_id, 'title'), null));
  end if;

  if not v_chat_cant_write and (not v_is_master or v_chat_parent_list = 'master_chats') then
    v_actions_list := v_actions_list || 
        format(', "chat_write": {"code": "chat_write", "name": "Написать", "disabled": false, '||
                '"params": {"chat_code": "%s"}, "user_params": [{"code": "message_text", "description": "Введите текст сообщения", "type": "string", "restrictions": {"multiline": true}}]}',
                v_chat_code);
  end if;

  if v_is_master and not pp_utils.is_in_group(in_actor_id, v_chat_code) then
    v_actions_list := v_actions_list || 
          format(', "chat_enter": {"code": "chat_enter", "name": "Следить", "disabled": false, '||
                  '"params": {"chat_code": "%s"}}',
                  v_chat_code);
  end if;

  if v_is_master then
    v_actions_list := v_actions_list || 
        format(', "chat_change_can_invite": {"code": "chat_change_settings", "name": "%s приглашать участников", "disabled": false, '||
                '"params": {"chat_code": "%s", "parameter": "can_invite", "value": "%s"}}',
                case when v_chat_can_invite then 'Запретить' else 'Разрешить' end,
                v_chat_code,
                case when v_chat_can_invite then 'off' else 'on' end);

    v_actions_list := v_actions_list || 
        format(', "chat_change_can_leave": {"code": "chat_change_settings", "name": "%s выходить из чата", "disabled": false, '||
                '"params": {"chat_code": "%s", "parameter": "can_leave", "value": "%s"}}',
                case when v_chat_can_leave then 'Запретить' else 'Разрешить' end,
                v_chat_code,
                case when v_chat_can_leave then 'off' else 'on' end);

    v_actions_list := v_actions_list || 
        format(', "chat_change_can_mute": {"code": "chat_change_settings", "name": "%s отключать уведомления", "disabled": false, %s'||
                '"params": {"chat_code": "%s", "parameter": "can_mute", "value": "%s"}}',
                case when v_chat_can_mute then 'Запретить' else 'Разрешить' end,
                case when v_chat_can_mute then '"warning": "Это действие включит уведомления для всех участников чата",' else '' end,
                v_chat_code,
                case when v_chat_can_mute then 'off' else 'on' end);

    v_actions_list := v_actions_list || 
        format(', "chat_change_can_rename": {"code": "chat_change_settings", "name": "%s переименование чата", "disabled": false, '||
                '"params": {"chat_code": "%s", "parameter": "can_rename", "value": "%s"}}',
                case when v_chat_can_rename then 'Запретить' else 'Разрешить' end,
                v_chat_code,
                case when v_chat_can_rename then 'off' else 'on' end);
  end if;

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_chat_temp_person_list(integer, integer);

create or replace function pallas_project.actgenerator_chat_temp_person_list(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
begin
  assert in_actor_id is not null;

  v_actions_list := v_actions_list || 
                ', "chat_add_person_back": {"code": "go_back", "name": "Назад к чату", "disabled": false, '||
                '"params": {}}';

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_chats(integer, integer);

create or replace function pallas_project.actgenerator_chats(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  if (v_object_code = 'chats' and pp_utils.is_in_group(in_actor_id, 'all_person')) 
    or pp_utils.is_in_group(in_actor_id, 'master') then
    v_actions_list := v_actions_list || 
      format(', "create_chat": {"code": "create_chat", "name": "Создать чат", "disabled": false, "params": {%s}}',
             case v_object_code when 'master_chats' then '"chat_is_master": true' else '' end
            );
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_debatle(integer, integer);

create or replace function pallas_project.actgenerator_debatle(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_person1 text := json.get_string_opt(data.get_attribute_value_for_share(in_object_id, 'debatle_person1'), null);
  v_person1_id integer := data.get_object_id_opt(v_person1);
  v_person2 text := json.get_string_opt(data.get_attribute_value_for_share(in_object_id, 'debatle_person2'), null);
  v_person2_id integer := data.get_object_id_opt(v_person2);
  v_judge text := json.get_string_opt(data.get_attribute_value_for_share(in_object_id, 'debatle_judge'), null);
  v_judge_id integer := data.get_object_id_opt(v_judge);
  v_is_master boolean := pp_utils.is_in_group(in_actor_id, 'master');
  v_debatle_code text;
  v_debatle_status text := json.get_string_opt(data.get_attribute_value_for_share(in_object_id, 'debatle_status'), null);
  v_title text := json.get_string_opt(data.get_raw_attribute_value_for_share(in_object_id, 'title'), '');
  v_subtitle text := json.get_string_opt(data.get_raw_attribute_value_for_share(in_object_id, 'subtitle'), '');
  v_chat_id integer;
  v_chat_length integer;
  v_chat_unread integer;
begin
  assert in_actor_id is not null;
  v_debatle_code := data.get_object_code(in_object_id);

  if v_is_master then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_instigator": {"code": "debatle_change_person", "name": "Изменить зачинщика", "disabled": false, '||
                '"params": {"debatle_code": "%s", "edited_person": "instigator"}}',
                v_debatle_code);
    v_actions_list := v_actions_list || 
        format(', "debatle_change_judge": {"code": "debatle_change_person", "name": "Изменить судью", "disabled": false, '||
                '"params": {"debatle_code": "%s", "edited_person": "judge"}}',
                v_debatle_code);
    v_actions_list := v_actions_list || 
        format(', "debatle_change_subtitle": {"code": "debatle_change_subtitle", "name": "Изменить место и время", "disabled": false, '||
                '"params": {"debatle_code": "%s"}, "user_params": [{"code": "subtitle", "description": "Введите место и время текстом", "type": "string", "default_value": "%s" }]}',
                v_debatle_code,
                v_subtitle);
  end if;

  if v_is_master or in_actor_id = v_person1_id and v_debatle_status in ('draft') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_opponent": {"code": "debatle_change_person", "name": "Изменить оппонента", "disabled": false, '||
                '"params": {"debatle_code": "%s", "edited_person": "opponent"}}',
                v_debatle_code);
    v_actions_list := v_actions_list || 
        format(', "debatle_change_theme": {"code": "debatle_change_theme", "name": "Изменить тему", "disabled": false, '||
                '"params": {"debatle_code": "%s"}, "user_params": [{"code": "title", "description": "Введите тему дебатла", "type": "string", "default_value": "%s", "restrictions": {"min_length": 1}}]}',
                v_debatle_code,
                v_title);
  end if;
  if v_is_master and v_debatle_status in ('draft', 'new') or in_actor_id = v_person1_id and v_debatle_status in ('draft') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_target_audience": {"code": "act_open_object", "name": "Изменить целевую аудиторию", "disabled": false, '||
                '"params": {"object_code": "%s"}}',
                v_debatle_code || '_target_audience');
  end if;

  if (v_is_master or in_actor_id = v_person1_id) and v_debatle_status in ('draft') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_status_new": {"code": "debatle_change_status", "name": "Отправить мастеру на подтверждение", "disabled": false, '||
                '"params": {"debatle_code": "%s", "new_status": "new"}}',
                v_debatle_code);
  end if;

  if v_is_master and v_debatle_status in ('new') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_status_future": {"code": "debatle_change_status", "name": "Подтвердить", "disabled": false, '||
                '"params": {"debatle_code": "%s", "new_status": "future"}}',
                v_debatle_code);
  end if;

  if (v_is_master or in_actor_id = v_judge_id) and v_debatle_status in ('future') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_status_vote": {"code": "debatle_change_status", "name": "Начать дебатл", "disabled": false, '||
                '"params": {"debatle_code": "%s", "new_status": "vote"}}',
                v_debatle_code);
  end if;

  if (v_is_master or in_actor_id = v_judge_id) and v_debatle_status in ('vote') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_status_vote_over": {"code": "debatle_change_status", "name": "Завершить голосование", "disabled": false, '||
                '"params": {"debatle_code": "%s", "new_status": "vote_over"}}',
                v_debatle_code);
  end if;

  if (v_is_master or in_actor_id = v_judge_id) and v_debatle_status in ('vote_over') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_status_closed": {"code": "debatle_change_status", "name": "Завершить дебатл", "disabled": false, '||
                '"params": {"debatle_code": "%s", "new_status": "closed"}}',
                v_debatle_code);
  end if;

  if v_is_master and v_debatle_status not in ('deleted') or in_actor_id = v_person1_id and v_debatle_status in ('draft') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_status_deleted": {"code": "debatle_change_status", "name": "Удалить", "disabled": false, '||
                '"params": {"debatle_code": "%s", "new_status": "deleted"}}',
                v_debatle_code);
  end if;

  if v_debatle_status in ('vote') 
    and not v_is_master
    and v_person1_id is not null
    and v_person2_id is not null
    and v_judge_id is not null
    and in_actor_id not in (v_person1_id, v_person2_id, v_judge_id) then
      v_actions_list := v_actions_list || 
        format(', "debatle_vote_person1": {"code": "debatle_vote", "name": "Голосовать за %s", "disabled": %s, '||
                '"params": {"debatle_code": "%s", "voted_person": "instigator"}}',
                json.get_string_opt(data.get_attribute_value(v_person1_id, 'title'), ''),
                case when json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person1_my_vote', in_actor_id), 0) > 0 then 'true' else 'false' end,
                v_debatle_code);
     v_actions_list := v_actions_list || 
        format(', "debatle_vote_person2": {"code": "debatle_vote", "name": "Голосовать за %s", "disabled": %s, '||
                '"params": {"debatle_code": "%s", "voted_person": "opponent"}}',
                json.get_string_opt(data.get_attribute_value(v_person2_id, 'title'), ''),
                case when json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person2_my_vote', in_actor_id), 0) > 0 then 'true' else 'false' end,
                v_debatle_code);
  end if;

  if v_debatle_status in ('vote', 'vote_over') and in_actor_id = v_judge_id or
   v_debatle_status in ('future', 'vote', 'vote_over', 'closed') and v_is_master then
      v_actions_list := v_actions_list || 
        format(', "debatle_change_bonuses1": {"code": "debatle_change_bonuses", "name": "Оштрафовать или наградить %s", "disabled": false, '||
                '"params": {"debatle_code": "%s", "judged_person": "instigator"}}',
                json.get_string_opt(data.get_attribute_value(v_person1_id, 'title'), ''),
                v_debatle_code);
     v_actions_list := v_actions_list || 
        format(', "debatle_change_bonuses2": {"code": "debatle_change_bonuses", "name": "Оштрафовать или наградить %s", "disabled": false, '||
                '"params": {"debatle_code": "%s", "judged_person": "opponent"}}',
                json.get_string_opt(data.get_attribute_value(v_person2_id, 'title'), ''),
                v_debatle_code);
  end if;

  if v_debatle_status in ('future', 'vote', 'vote_over', 'closed') then
    v_chat_id := data.get_object_id(v_debatle_code || '_chat');
    if v_chat_id is not null then
      v_chat_length := json.get_integer_opt(data.get_attribute_value(v_chat_id, 'system_chat_length'), 0);
      v_chat_unread := json.get_integer_opt(data.get_attribute_value(v_chat_id, 'chat_unread_messages', in_actor_id), null);
      v_actions_list := v_actions_list || 
          format(', "debatle_chat": {"code": "chat_enter", "name": "Обсудить%s", "disabled": false, '||
                  '"params": {"object_code": "%s"}}',
                  case when v_chat_length = 0 then ''
                  when v_chat_length > 0 and v_chat_unread is null then ' (' || v_chat_length || ')'
                  else ' (' || v_chat_length || ', непрочитанных ' || v_chat_unread || ')' 
                  end,
                  v_debatle_code);
    end if;
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_debatle_target_audience(integer, integer);

create or replace function pallas_project.actgenerator_debatle_target_audience(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
begin
  assert in_actor_id is not null;

  v_actions_list := v_actions_list || 
                ', "go_back": {"code": "go_back", "name": "Вернуться к дебатлу", "disabled": false, '||
                '"params": {}}';

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_debatle_target_audience_content(integer, integer, integer);

create or replace function pallas_project.actgenerator_debatle_target_audience_content(in_object_id integer, in_list_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_is_master boolean;
  v_master_group_id integer := data.get_object_id('master');
  v_debatle_code text := replace(data.get_object_code(in_object_id), '_target_audience', '');
  v_debatle_id integer := data.get_object_id(v_debatle_code);
  v_list_code text := data.get_object_code(in_list_object_id);
  v_debatle_status text := json.get_string_opt(data.get_attribute_value_for_share(v_debatle_id, 'debatle_status'),'');
  v_system_debatle_target_audience text[] := json.get_string_array_opt(data.get_attribute_value_for_share(v_debatle_id, 'system_debatle_target_audience'), array[]::text[]);
  v_is_in_array boolean;
begin
  assert in_actor_id is not null;

  v_is_master := pp_utils.is_in_group(in_actor_id, 'master');
  if v_debatle_status in ('draft', 'new') then
    v_is_in_array := (array_position(v_system_debatle_target_audience, v_list_code) is not null);
    v_actions_list := v_actions_list ||
            format(', "debatle_del_audience_group": {"code": "debatle_change_audience_group", "name": "-", "disabled": %s, '||
                    '"params": {"debatle_code": "%s", "list_code": "%s", "add_or_del": "del"}}',
                    case when v_is_in_array then 'false' else 'true' end,
                    v_debatle_code,
                    v_list_code);
      v_actions_list := v_actions_list || 
            format(', "debatle_add_audience_group": {"code": "debatle_change_audience_group", "name": "+", "disabled": %s, '||
                    '"params": {"debatle_code": "%s", "list_code": "%s", "add_or_del": "add"}}',
                    case when v_is_in_array then 'true' else 'false' end,
                    v_debatle_code,
                    v_list_code);
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_debatle_temp_bonus_list(integer, integer);

create or replace function pallas_project.actgenerator_debatle_temp_bonus_list(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_debatle_change_code text := data.get_object_code(in_object_id);
  v_judged_person text := json.get_string(data.get_attribute_value(in_object_id, 'debatle_temp_bonus_list_person'));
begin
  assert in_actor_id is not null;

  v_actions_list := v_actions_list || 
                ', "debatle_change_bonus_back": {"code": "go_back", "name": "Вернуться к дебатлу", "disabled": false, '||
                '"params": {}}';
  v_actions_list := v_actions_list || 
                ', "debatle_change_other_bonus": {"code": "debatle_change_other_bonus", "name": "Добавить произвольный бонус", "disabled": false, '||
                 format('"params": {"debatle_change_code": "%s", "judged_person": "%s", "bonus_or_fine": "bonus"},'||
                        ' "user_params": [{"code": "bonus_reason", "description": "Описание бонуса", "type": "string", "restrictions":{"min_length": 5}},{"code": "votes", "description": "Количество прибавляемых голосов", "type": "integer", "default_value": %s }]}',
                        v_debatle_change_code,
                        v_judged_person,
                        1);
  v_actions_list := v_actions_list || 
                ', "debatle_change_other_fine": {"code": "debatle_change_other_bonus", "name": "Добавить произвольный штраф", "disabled": false, '||
                format('"params": {"debatle_change_code": "%s", "judged_person": "%s", "bonus_or_fine": "fine"},'||
                ' "user_params": [{"code": "bonus_reason", "description": "Описание штрафа", "type": "string", "restrictions":{"min_length": 5}},{"code": "votes", "description": "Количество вычитаемых голосов", "type": "integer", "default_value": %s }]}',
                v_debatle_change_code,
                v_judged_person,
                1);


  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_debatle_temp_person_list(integer, integer);

create or replace function pallas_project.actgenerator_debatle_temp_person_list(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_person1_id integer;
  v_is_master boolean;
  v_debatle_code text;
  v_debatle_status text;
begin
  assert in_actor_id is not null;

  v_actions_list := v_actions_list || 
                ', "debatle_change_person_back": {"code": "go_back", "name": "Отмена", "disabled": false, '||
                '"params": {}}';

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_debatles(integer, integer);

create or replace function pallas_project.actgenerator_debatles(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
begin
  assert in_actor_id is not null;

  if pp_utils.is_in_group(in_actor_id, 'all_person') or pp_utils.is_in_group(in_actor_id, 'master') then
    v_actions_list := v_actions_list || 
      ', "debatle_create": {"code": "debatle_create", "name": "Инициировать дебатл", "disabled": false, '||
      '"params": {}, "user_params": [{"code": "title", "description": "Введите тему дебатла", "type": "string" }]}';
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_document(integer, integer);

create or replace function pallas_project.actgenerator_document(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_is_master boolean;
  v_master_group_id integer := data.get_object_id('master');
  v_document_code text := data.get_object_code(in_object_id);
  v_document_author integer := json.get_integer(data.get_attribute_value(in_object_id, 'system_document_author'));
  v_document_category text := json.get_string(data.get_attribute_value_for_share(in_object_id, 'document_category'));
  v_document_status text := json.get_string_opt(data.get_attribute_value_for_share(in_object_id, 'document_status'),'');
  v_system_document_participants jsonb := data.get_attribute_value_for_share(in_object_id, 'system_document_participants');
  v_system_document_is_my boolean := json.get_boolean_opt(data.get_raw_attribute_value_for_share(in_object_id, 'system_document_is_my', in_actor_id), false);
  v_document_list_content text[];
  v_my_documents_id integer := data.get_object_id('my_documents');
  v_official_documents_id integer := data.get_object_id('official_documents');
  v_rules_documents_id integer := data.get_object_id('rules_documents');
begin
  assert in_actor_id is not null;

  v_is_master := pp_utils.is_in_group(in_actor_id, 'master');
  if v_document_status <> 'deleted' then
    if v_is_master or (in_actor_id = v_document_author and (v_document_category = 'private' or v_document_status = 'draft')) then
      v_actions_list := v_actions_list || 
          format(', "document_edit": {"code": "document_edit", "name": "Редактировать", "disabled": false, "params": {"document_code": "%s"}, 
  "user_params": [{"code": "title", "description": "Заголовок", "type": "string", "restrictions": {"min_length": 1}, "default_value": "%s"},
  {"code": "document_text", "description": "Текст документа", "type": "string", "restrictions": {"min_length": 1, "multiline": true}, "default_value": %s}]}',
                  v_document_code,
                  json.get_string_opt(data.get_raw_attribute_value_for_share(in_object_id, 'title'), null),
                  coalesce(data.get_attribute_value_for_share(in_object_id, 'document_text')::text, '""'));

      v_actions_list := v_actions_list || 
          format(', "document_delete": {"code": "document_delete", "name": "Удалить", "disabled": false, "warning": "Документ исчезнет безвозвратно. Точно удаляем?", '||
                  '"params": {"document_code": "%s"}}',
                  v_document_code);

      if v_document_category = 'private' then
        v_actions_list := v_actions_list || 
          format(', "document_make_official": {"code": "document_make_official", "name": "Перевести в официальные", "disabled": false, '||
                  '"params": {"document_code": "%s"}}',
                  v_document_code);
      end if;
    end if;

    if v_is_master and v_document_category = 'private' then
      v_actions_list := v_actions_list || 
          format(', "document_make_rule": {"code": "document_make_rule", "name": "Перенести в правила", "disabled": false, "warning": "Документ перенесётся в правила для всех, у кого он есть в документах. Переносим?", '||
                  '"params": {"document_code": "%s"}}',
                  v_document_code);
    end if;

    v_actions_list := v_actions_list || 
            format(', "document_share_list": {"code": "document_share_list", "name": "Поделиться", "disabled": false, '||
                    '"params": {"document_code": "%s"}}',
                    v_document_code);

    if not v_is_master and v_document_category in ('private', 'official', 'rule') and not v_system_document_is_my then
      v_actions_list := v_actions_list || 
              format(', "document_add_to_my": {"code": "document_add_to_my", "name": "Добавить себе", "disabled": false, '||
                    '"params": {"document_code": "%s"}}',
                    v_document_code);
    end if;

    if v_document_category = 'official' and v_document_status = 'draft' and (v_is_master or in_actor_id = v_document_author) then
      v_actions_list := v_actions_list || 
          format(', "document_add_signers": {"code": "act_open_object", "name": "Добавить участников", "disabled": false, '||
                  '"params": {"object_code": "%s"}}',
                  v_document_code || '_signers_list');

      v_actions_list := v_actions_list || 
          format(', "document_send_to_sign": {"code": "document_send_to_sign", "name": "Отправить на подпись", "disabled": %s, "warning": "Всем, кому нужно расписаться, будут отправлены уведомления со ссылкой на документ. Редактирование документа станет невозможным. Продолжаем?",'||
                 '"params": {"document_code": "%s"}}',
                 (case when v_system_document_participants <> jsonb '{}' then 'false' else 'true' end),
                 v_document_code);
    end if;

    if v_document_category = 'official' and v_document_status = 'signing' and (v_is_master or in_actor_id = v_document_author) then
      v_actions_list := v_actions_list || 
          format(', "document_back_to_editing": {"code": "document_back_to_editing", "name": "Вернуть на редактирование", "disabled": false, "warning": "Все подписи будут отозваны. Вы уверены, что хотите вернуть документ на редактирование?",'||
                  '"params": {"document_code": "%s"}}',
                  v_document_code);
    end if;

    if v_document_category = 'official' 
    and v_document_status = 'signing' 
    and not json.get_boolean_opt(v_system_document_participants, data.get_object_code(in_actor_id), null) then
      v_actions_list := v_actions_list || 
        format(', "document_sign": {"code": "document_sign", "name": "Подписать", "disabled": false, "warning": "Подпись нельзя отозвать назад, если только документ не будет изменён. Вы уверены, что хотите подписать этот документ?",'||
               '"params": {"document_code": "%s"}}',
               v_document_code);
    end if;
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_document_content(integer, integer, integer);

create or replace function pallas_project.actgenerator_document_content(in_object_id integer, in_list_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_is_master boolean;
  v_master_group_id integer := data.get_object_id('master');
  v_document_code text := data.get_object_code(in_object_id);
  v_list_code text := data.get_object_code(in_list_object_id);
  v_document_author integer := json.get_integer(data.get_attribute_value(in_object_id, 'system_document_author'));
  v_document_category text := json.get_string(data.get_attribute_value_for_share(in_object_id, 'document_category'));
  v_document_status text := json.get_string_opt(data.get_attribute_value_for_share(in_object_id, 'document_status'),'');
  v_system_document_participants jsonb := data.get_attribute_value_for_share(in_object_id, 'system_document_participants');
begin
  assert in_actor_id is not null;

  v_is_master := pp_utils.is_in_group(in_actor_id, 'master');
  if v_document_status <> 'deleted' then
    if v_document_category = 'official' and v_document_status = 'draft' then
      if (v_is_master or in_actor_id = v_document_author) then
        v_actions_list := v_actions_list || 
            format(', "document_delete_signer": {"code": "document_delete_signer", "name": "Удалить", "disabled": false, '||
                    '"params": {"document_code": "%s", "list_code": "%s"}}',
                    v_document_code,
                    v_list_code);
      end if;
      if v_is_master and not json.get_boolean_opt(v_system_document_participants, v_list_code, true) then
        v_actions_list := v_actions_list || 
            format(', "document_sign_for_signer": {"code": "document_sign_for_signer", "name": "Подписать", "disabled": false, '||
                    '"params": {"document_code": "%s", "list_code": "%s"}}',
                    v_document_code,
                    v_list_code);
      end if;
    end if;
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_document_signers_list(integer, integer);

create or replace function pallas_project.actgenerator_document_signers_list(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
begin
  assert in_actor_id is not null;

  v_actions_list := v_actions_list || 
                ', "go_back": {"code": "go_back", "name": "Назад к документу", "disabled": false, '||
                '"params": {}}';

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_document_temp_share_list(integer, integer);

create or replace function pallas_project.actgenerator_document_temp_share_list(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_share_list_code text := data.get_object_code(in_object_id);
  v_system_document_temp_share_list integer[] := json.get_integer_array_opt(data.get_attribute_value_for_share(in_object_id, 'system_document_temp_share_list'),array[]::integer[]);
begin
  assert in_actor_id is not null;

  v_actions_list := v_actions_list || 
                ', "go_back": {"code": "go_back", "name": "Передумал делиться", "disabled": false, '||
                '"params": {}}';

  v_actions_list := v_actions_list || 
          format(', "document_share": {"code": "document_share", "name": "Поделиться", "disabled": %s, "warning": "Ссылка на документ будет отправлена выбранным лицам, и забрать её назад вы не сможете. Продолжаем?",'||
                  '"params": {"share_list_code": "%s"}}',
                  (case when coalesce(array_length(v_system_document_temp_share_list, 1), 0) = 0 then 'true' else 'false' end),
                  v_share_list_code);
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_documents(integer, integer);

create or replace function pallas_project.actgenerator_documents(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  v_actions_list := v_actions_list || 
    ', "document_create": {"code": "document_create", "name": "Создать документ", "disabled": false, 
     "params": {}, "user_params": [{"code": "title", "description": "Введите заголовок документа", "type": "string", "restrictions": {"min_length": 1}}]}';

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_lottery(integer, integer);

create or replace function pallas_project.actgenerator_lottery(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_status text := json.get_string(data.get_attribute_value_for_share(in_object_id, 'lottery_status'));
  v_master boolean;
  v_economy_type text;
  v_lottery_owner text;
  v_ticket_price integer;
  v_money bigint;
  v_actions jsonb := '{}';
begin
  if v_status = 'active' then
    v_master := pp_utils.is_in_group(in_actor_id, 'master');

    if v_master then
      v_actions :=
        v_actions ||
        jsonb '{
          "finish_lottery": {
            "code": "finish_lottery",
            "name": "Завершить лотерею",
            "disabled": false,
            "warning": "Уверены, что хотите завершить лотерею?",
            "params": null
          },
          "cancel_lottery": {
            "code": "cancel_lottery",
            "name": "Отменить лотерею",
            "disabled": false,
            "warning": "Точно отменить?",
            "params": null
          }
        }';
    else
      v_economy_type := json.get_string_opt(data.get_attribute_value_for_share(in_actor_id, 'system_person_economy_type'), null);
      v_lottery_owner := json.get_string(data.get_attribute_value_for_share(in_object_id, 'system_lottery_owner'));

      if data.get_object_id(v_lottery_owner) = in_actor_id then
        v_actions :=
          v_actions ||
          jsonb '{
            "finish_lottery": {
              "code": "finish_lottery",
              "name": "Завершить лотерею",
              "disabled": false,
              "warning": "Уверены, что хотите завершить лотерею?",
              "params": null
            }
          }';
      end if;

      if v_economy_type = 'asters' then
        v_ticket_price := data.get_integer_param('lottery_ticket_price');
        v_money := json.get_bigint(data.get_attribute_value_for_share(in_actor_id, 'system_money'));

        if v_money < v_ticket_price then
          v_actions :=
            v_actions ||
            format(
              '{
                "buy_lottery_ticket": {
                  "name": "Купить лотерейный билет (%s)",
                  "disabled": true
                }
              }',
              pp_utils.format_money(v_ticket_price::bigint)
              )::jsonb;
        else
          v_actions :=
            v_actions ||
            format(
              '{
                "buy_lottery_ticket": {
                  "code": "buy_lottery_ticket",
                  "name": "Купить лотерейный билет (%s)",
                  "disabled": false,
                  "warning": "Увеличить шанс выиграть гражданство ООН всего за %s?",
                  "params": null
                }
              }',
              pp_utils.format_money(v_ticket_price::bigint),
              pp_utils.format_money(v_ticket_price::bigint))::jsonb;
        end if;
      end if;
    end if;
  end if;

  return v_actions;
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_menu(integer, integer);

create or replace function pallas_project.actgenerator_menu(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_actor_code text := data.get_object_code(in_actor_id);
  v_actions jsonb := '{}';
  v_is_master boolean := pp_utils.is_in_group(in_actor_id, 'master');
  v_economy_type text := json.get_string_opt(data.get_attribute_value_for_share(in_actor_id, 'system_person_economy_type'), null);
begin
  assert in_actor_id is not null;

  -- Тут порядок не важен, т.к. он задаётся в шаблоне

  if v_actor_code = 'anonymous' then
    v_actions :=
      v_actions ||
      jsonb '{"login": {"code": "login", "name": "Войти", "disabled": false, "params": {}, "user_params": [{"code": "password", "description": "Введите пароль", "type": "string", "restrictions": {"password": true}}]}}';
  elsif v_is_master or pp_utils.is_in_group(in_actor_id, 'all_person') then
    if not v_is_master then
      v_actions :=
        v_actions ||
        format(
          '{
            "profile": {"code": "act_open_object", "name": "Профиль", "disabled": false, "params": {"object_code": "%s"}},
            "statuses": {"code": "act_open_object", "name": "Статусы", "disabled": false, "params": {"object_code": "%s_statuses"}}
          }',
          v_actor_code,
          v_actor_code)::jsonb;
      v_actions :=
        v_actions ||
        jsonb '{
          "chats": {"code": "act_open_object", "name": "Чаты", "disabled": false, "params": {"object_code": "chats"}},
          "master_chats": {"code": "act_open_object", "name": "Связь с мастерами", "disabled": false, "params": {"object_code": "master_chats"}},
          "important_notifications": {"code": "act_open_object", "name": "Важные уведомления", "disabled": false, "params": {"object_code": "important_notifications"}}
        }';

      if v_economy_type != 'fixed' then
        v_actions :=
          v_actions ||
          format(
            '{
              "next_statuses": {"code": "act_open_object", "name": "Покупка статусов", "disabled": false, "params": {"object_code": "%s_next_statuses"}}
            }',
            v_actor_code)::jsonb;
        if v_economy_type != 'un' then
          v_actions :=
            v_actions ||
            format(
              '{
                "transactions": {"code": "act_open_object", "name": "История транзакций", "disabled": false, "params": {"object_code": "%s_transactions"}}
              }',
              v_actor_code)::jsonb;
        end if;
      end if;
    else
      v_actions :=
        v_actions ||
        jsonb '{
          "chats": {"code": "act_open_object", "name": " Отслеживаемые игровые чаты", "disabled": false, "params": {"object_code": "chats"}},
          "all_chats": {"code": "act_open_object", "name": "Все игровые чаты", "disabled": false, "params": {"object_code": "all_chats"}},
          "master_chats": {"code": "act_open_object", "name": "Мастерские чаты", "disabled": false, "params": {"object_code": "master_chats"}}
        }';
    end if;

    declare
      v_notification_count integer := json.get_integer(data.get_attribute_value_for_share(in_actor_id, 'system_person_notification_count'));
    begin
      if v_notification_count > 0 then
        v_actions :=
          v_actions ||
          format(
            '{
              "notifications": {"code": "act_open_object", "name": "🔥 Уведомления 🔥 (%s)", "disabled": false, "params": {"object_code": "notifications"}}
            }',
            v_notification_count)::jsonb;
      end if;
    end;

    declare
      v_lottery_id integer := data.get_object_id('lottery');
      v_lottery_status text := json.get_string(data.get_attribute_value_for_share(v_lottery_id, 'lottery_status'));
      v_generate boolean := false;
      v_lottery_owner text;
    begin
      if v_lottery_status = 'active' then
        if v_is_master or v_economy_type = 'asters' then
          v_generate := true;
        else
          v_lottery_owner := json.get_string(data.get_attribute_value_for_share(v_lottery_id, 'system_lottery_owner'));
          if v_lottery_owner = v_actor_code then
            v_generate := true;
          end if;
        end if;

        if v_generate then
          v_actions :=
            v_actions ||
            jsonb '{
              "lottery": {"code": "act_open_object", "name": "🇺🇳 Лотерея гражданства 🇺🇳", "disabled": false, "params": {"object_code": "lottery"}}
            }';
        end if;
      end if;
    end;

    declare
      v_groups jsonb := data.get_raw_attribute_value_for_share(data.get_object_id(v_actor_code || '_my_organizations'), 'content');
    begin
      if v_groups != jsonb '[]' then
        v_actions :=
          v_actions ||
          format(
            '{
              "my_organizations": {"code": "act_open_object", "name": "Мои организации", "disabled": false, "params": {"object_code": "%s"}}
            }',
            v_actor_code || '_my_organizations')::jsonb;
      end if;
    end;

    v_actions :=
      v_actions ||
      jsonb '{
        "debatles": {"code": "act_open_object", "name": "Дебатлы", "disabled": false, "params": {"object_code": "debatles"}},
        "documents": {"code": "act_open_object", "name": "Документы", "disabled": false, "params": {"object_code": "documents"}},
        "logout": {"code": "logout", "name": "Выход", "disabled": false, "params": {}}
      }';
  end if;

  v_actions :=
    v_actions ||
    jsonb '{
      "persons": {"code": "act_open_object", "name": "Люди", "disabled": false, "params": {"object_code": "persons"}},
      "districts": {"code": "act_open_object", "name": "Районы", "disabled": false, "params": {"object_code": "districts"}},
      "organizations": {"code": "act_open_object", "name": "Организации", "disabled": false, "params": {"object_code": "organizations"}}
    }';

  return v_actions;
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_next_statuses(integer, integer);

create or replace function pallas_project.actgenerator_next_statuses(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_master boolean := pp_utils.is_in_group(in_actor_id, 'master');
  v_economy_type text;
  v_coins integer;
  v_money integer;
  v_coin_price integer;
  v_status_name text;
  v_actions jsonb := jsonb '{}';
begin
  if not v_master then
    v_economy_type := json.get_string(data.get_attribute_value_for_share(in_actor_id, 'system_person_economy_type'));

    if v_economy_type = 'un' then
      v_coins := json.get_integer(data.get_attribute_value_for_share(in_actor_id, 'system_person_coin'));
    else
      v_money := json.get_integer(data.get_attribute_value_for_share(in_actor_id, 'system_money'));
      v_coin_price := data.get_integer_param('coin_price');
    end if;
  end if;

  for v_status_name in
  (
    select value
    from unnest(array['life_support', 'health_care', 'recreation', 'police', 'administrative_services']) a(value)
  )
  loop
    declare
      v_status_prices integer[] := data.get_integer_array_param(v_status_name || '_status_prices');
      v_status integer := json.get_integer(data.get_attribute_value_for_share(in_object_id, v_status_name || '_next_status'));
      v_price bigint;
      v_too_expensive boolean;
      v_action record;
    begin
      assert array_length(v_status_prices, 1) = 3;
      assert v_status in (0, 1, 2, 3);

      if v_master then
        -- todo установка статусов
      else
        v_price := 0;

        for v_action in
        (
          select
            value,
            (case when value = 1 then 'bronze' when value = 2 then 'silver' else 'gold' end) action_suffix,
            (case when value = 1 then 'бронзовый' when value = 2 then 'серебряный' else 'золотой' end) description
          from unnest(array[1, 2, 3]) a(value)
        )
        loop
          if v_status < v_action.value then
            v_price := v_price + v_status_prices[v_action.value] * (case when v_economy_type = 'un' then 1 else v_coin_price end);
            v_too_expensive := (case when v_economy_type = 'un' then v_coins < v_price else v_money < v_price end);

            if v_too_expensive then
              v_actions :=
                v_actions ||
                format(
                  '{
                    "%s_%s": {
                      "name": "Купить %s статус (%s)",
                      "disabled": true
                    }
                  }',
                  v_status_name,
                  v_action.action_suffix,
                  v_action.description,
                  v_price)::jsonb;
            else
              v_actions :=
                v_actions ||
                format(
                  '{
                    "%s_%s": {
                      "code": "buy_status",
                      "name": "Купить %s статус (%s)",
                      "disabled": false,
                      "warning": "Вы действительно хотите купить %s статус за %s?",
                      "params": {"status_name": "%s", "value": %s}
                    }
                  }',
                  v_status_name,
                  v_action.action_suffix,
                  v_action.description,
                  (case when v_economy_type = 'un' then v_price::text else pp_utils.format_money(v_price) end),
                  v_action.description,
                  (case when v_economy_type = 'un' then v_price || ' ' || pp_utils.add_word_ending('коин', v_price) else pp_utils.format_money(v_price) end),
                  v_status_name,
                  v_action.value)::jsonb;
            end if;
          end if;
        end loop;
      end if;
    end;
  end loop;

  return v_actions;
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_notifications(integer, integer);

create or replace function pallas_project.actgenerator_notifications(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
begin
  return jsonb '{"clear_notifications": {"code": "clear_notifications", "name": "Очистить", "disabled": false, "params": null}}';
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_notifications_content(integer, integer, integer);

create or replace function pallas_project.actgenerator_notifications_content(in_object_id integer, in_list_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
begin
  return format('{"remove_notification": {"code": "remove_notification", "name": "Удалить", "disabled": false, "params": "%s"}}', data.get_object_code(in_list_object_id))::jsonb;
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_organization(integer, integer);

create or replace function pallas_project.actgenerator_organization(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_master boolean := pp_utils.is_in_group(in_actor_id, 'master');
  v_actor_economy_type text := json.get_string_opt(data.get_attribute_value_for_share(in_actor_id, 'system_person_economy_type'), null);
  v_actor_money bigint;
  v_has_read_rights boolean := pallas_project.can_see_organization(in_actor_id, v_object_code);
  v_actions jsonb := jsonb '{}';
begin
  if v_master or v_has_read_rights then
    v_actions :=
      v_actions ||
      format(
        '{
          "show_transactions": {
            "code": "act_open_object",
            "name": "Посмотреть историю транзакций",
            "params": {
              "object_code": "%s_transactions"
            }
          }
        }',
        v_object_code)::jsonb;
  end if;

  if v_actor_economy_type in ('asters', 'mcr') then
    v_actor_money := json.get_bigint(data.get_attribute_value_for_share(in_actor_id, 'system_money'));
    if v_actor_money <= 0 then
      v_actions :=
        v_actions ||
        jsonb '{
          "transfer_money": {
            "name": "Перевести деньги",
            "disabled": true
          }
        }';
    else
      v_actions :=
        v_actions ||
        format(
          '{
            "transfer_money": {
              "code": "transfer_money",
              "name": "Перевести деньги",
              "params": "%s",
              "user_params": [
                {
                  "code": "sum",
                  "description": "Сумма, UN$",
                  "type": "integer",
                  "restrictions": {"min_value": 1, "max_value": %s}
                },
                {
                  "code": "comment",
                  "description": "Комментарий",
                  "type": "string",
                  "restrictions": {"max_length": 1000, "multiline": true}
                }
              ]
            }
          }',
          v_object_code,
          v_actor_money)::jsonb;
    end if;
  end if;

  return v_actions;
end;
$$
language plpgsql;

-- drop function pallas_project.actgenerator_person(integer, integer);

create or replace function pallas_project.actgenerator_person(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_master boolean := pp_utils.is_in_group(in_actor_id, 'master');
  v_economy_type jsonb := data.get_attribute_value_for_share(in_object_id, 'system_person_economy_type');
  v_actor_economy_type text;
  v_actor_money bigint;
  v_tax integer;
  v_actions jsonb := jsonb '{}';
begin
  if v_master then
    if v_economy_type is not null then
      v_actions :=
        v_actions ||
        format('{
          "open_current_statuses": {
            "code": "act_open_object",
            "name": "Посмотреть текущие статусы",
            "disabled": false,
            "params": {
              "object_code": "%s_statuses"
            }
          }
        }', v_object_code)::jsonb;
      if v_economy_type != jsonb '"fixed"' then
        v_actions :=
          v_actions ||
          format('{
            "open_next_statuses": {
              "code": "act_open_object",
              "name": "Посмотреть купленные статусы на следующий цикл",
              "disabled": false,
              "params": {
                "object_code": "%s_next_statuses"
              }
            }
          }', v_object_code)::jsonb;
        if v_economy_type != jsonb '"un"' then
          v_actions :=
            v_actions ||
            format('{
              "open_transactions": {
                "code": "act_open_object",
                "name": "Посмотреть историю транзакций",
                "disabled": false,
                "params": {
                  "object_code": "%s_transactions"
                }
              }
            }', v_object_code)::jsonb;
        end if;
      end if;
    end if;
  else
    if in_object_id != in_actor_id and v_economy_type in (jsonb '"asters"', jsonb '"mcr"') then
      v_actor_economy_type := json.get_string_opt(data.get_attribute_value_for_share(in_actor_id, 'system_person_economy_type'), null);
      if v_actor_economy_type in ('asters', 'mcr') then
        v_actor_money := json.get_bigint(data.get_attribute_value_for_share(in_actor_id, 'system_money'));
        if v_actor_money <= 0 then
          v_actions :=
            v_actions ||
            jsonb '{
              "transfer_money": {
                "name": "Перевести деньги",
                "disabled": true
              }
            }';
        else
          v_tax := pallas_project.get_person_tax_for_share(in_object_id);
          v_actions :=
            v_actions ||
            format(
              '{
                "transfer_money": {
                  "code": "transfer_money",
                  "name": "Перевести деньги",
                  "warning": "С суммы перевода будет списан налог в размере %s%% с округлением вверх, продолжить?",
                  "params": "%s",
                  "user_params": [
                    {
                      "code": "sum",
                      "description": "Сумма, UN$",
                      "type": "integer",
                      "restrictions": {"min_value": 1, "max_value": %s}
                    },
                    {
                      "code": "comment",
                      "description": "Комментарий",
                      "type": "string",
                      "restrictions": {"max_length": 1000, "multiline": true}
                    }
                  ]
                }
              }',
              v_tax,
              v_object_code,
              v_actor_money)::jsonb;
        end if;
      end if;
    end if;
  end if;

  return v_actions;
end;
$$
language plpgsql;

-- drop function pallas_project.can_see_organization(integer, text);

create or replace function pallas_project.can_see_organization(in_person_id integer, in_organization_code text)
returns boolean
stable
as
$$
declare
  v_has_read_rights boolean := false;
begin
  select true
  into v_has_read_rights
  where exists (
    select 1
    from data.object_objects
    where
      object_id = in_person_id and
      parent_object_id in (
        data.get_object_id(in_organization_code || '_head'),
        data.get_object_id(in_organization_code || '_economist'),
        data.get_object_id(in_organization_code || '_auditor'),
        data.get_object_id(in_organization_code || '_temporary_auditor')));

  return v_has_read_rights;
end;
$$
language plpgsql;

-- drop function pallas_project.change_aster_to_un(integer, integer);

create or replace function pallas_project.change_aster_to_un(in_aster_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_base_coins integer := data.get_integer_param('base_un_coins');
  v_life_support_prices integer[] := data.get_integer_array_param('life_support_status_prices');
  v_person_economy_type jsonb := data.get_attribute_value_for_update(in_aster_id, 'system_person_economy_type');
  v_reason text := 'Смена гражданства';
  v_un_hints_id integer;
  v_aster_code text := data.get_object_code(in_aster_id);
begin
  assert v_person_economy_type = jsonb '"asters"';

  -- Начисление коинов
  perform pallas_project.change_coins(in_aster_id, v_base_coins - v_life_support_prices[1], in_actor_id, v_reason);
  -- Сброс статусов следующего цикла
  perform data.change_object_and_notify(
    data.get_object_id(v_aster_code || '_next_statuses'),
    '[
      {"code": "money"},
      {"code": "life_support_next_status", "value": 1},
      {"code": "health_care_next_status", "value": 0},
      {"code": "recreation_next_status", "value": 0},
      {"code": "police_next_status", "value": 0},
      {"code": "administrative_services_next_status", "value": 0}
    ]',
    in_actor_id,
    v_reason);
  -- Смена типа экономики
  perform data.change_object_and_notify(
    in_aster_id,
    format(
      '[
        {"code": "person_state", "value": "un"},
        {"code": "person_un_rating", "value": %s}, 
        {"code": "system_person_economy_type", "value": "un"},
        {"code": "person_economy_type", "value": "un", "value_object_code": "master"},
        {"code": "system_money"},
        {"code": "money", "value_object_id": %s},
        {"code": "money", "value_object_code": "master"},
        {"code": "system_person_deposit_money"},
        {"code": "person_deposit_money", "value_object_id": %s},
        {"code": "person_deposit_money", "value_object_code": "master"}
      ]',
      data.get_integer_param('base_un_rating'),
      in_aster_id,
      in_aster_id)::jsonb);
  -- Уведомление
  v_un_hints_id :=
    data.create_object(
      null,
      format(
        '[
          {"code": "type", "value": "un_citizen_hints"},
          {"code": "is_visible", "value": true, "value_object_id": %s},
          {"code": "title", "value": "Советы для получивших гражданство"},
          {"code": "description", "value": "Уважаемый гражданин!\n\nТеперь вы являетесь полноценным представителем ООН, а значит, можете работать на благо всего общества.\nПозвольте дать вам несколько советов:\n1. Ваши статусы на следующий цикл выставлены в значение по умолчанию, также вам начислено количество коинов, соответствующее вашему рейтингу гражданина. Не забудьте их [потратить](babcom:%s_next_statuses)!\n2. Гражданин не просто может, но *должен* работать. Найдите работу, чтобы ваш рейтинг не падал, а вы не потеряли с таким трудом приобретённое гражданство.\n3. Работайте лучше. Чем лучше вы работаете, тем быстрее растёт ваш рейтинг и тем более ответственные должности вы можете занимать.\n\nНадеемся на долгое сотрудничетво, ваши коллеги из ООН!"},
          {"code": "template", "value": {"title": "title", "groups": [{"code": "group", "attributes": ["description"]}]}}
        ]',
        in_aster_id,
        v_aster_code)::jsonb);
  perform pp_utils.add_notification(in_aster_id, 'Вам доступна памятка гражданина ООН, не забудьте ознакомиться!', v_un_hints_id, true);
end;
$$
language plpgsql;

-- drop function pallas_project.change_chat_person_list_on_person(integer, text, boolean, boolean);

create or replace function pallas_project.change_chat_person_list_on_person(in_chat_id integer, in_chat_title text, in_is_master_chat boolean, in_is_current_object boolean default false)
returns jsonb[]
volatile
as
$$
declare
  v_chat_person_list_id integer := data.get_object_id(data.get_object_code(in_chat_id) || '_person_list'); 
  v_changes jsonb[];
  v_content text[];
  v_persons text := '';
  v_chat_can_invite boolean := json.get_boolean_opt(data.get_attribute_value_for_share(in_chat_id, 'system_chat_can_invite'), false);
  v_master_group_id integer := data.get_object_id('master');
begin
  -- Меняем привязанный к чату список для участников
  v_changes := array[]::jsonb[];
  if in_chat_title is not null then 
    v_changes := array_append(v_changes, data.attribute_change2jsonb('title', to_jsonb('Участники чата ' || in_chat_title)));
  end if;

  v_content := pallas_project.get_chat_possible_persons(in_chat_id, in_is_master_chat);
  if v_chat_can_invite then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('content', to_jsonb(v_content), v_master_group_id));
    v_changes := array_append(v_changes, data.attribute_change2jsonb('content', to_jsonb(v_content), in_chat_id));
  elsif not in_is_master_chat then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('content', to_jsonb(v_content), v_master_group_id));
  end if;

  v_persons := pallas_project.get_chat_persons_text(in_chat_id, not in_is_master_chat);
  v_changes := array_append(v_changes, data.attribute_change2jsonb('chat_person_list_persons', to_jsonb(v_persons)));

  if not in_is_current_object then
    perform data.change_object_and_notify(v_chat_person_list_id, 
                                          to_jsonb(v_changes),
                                          null);
  end if;
                                      return v_changes;
end;
$$
language plpgsql;

-- drop function pallas_project.change_coins(integer, integer, integer, text);

create or replace function pallas_project.change_coins(in_object_id integer, in_new_value integer, in_actor_id integer, in_reason text)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_diffs jsonb;
begin
  -- Изменяемые объекты: сам объект, его страница покупки статусов
  v_diffs :=
    data.change_object(
      in_object_id,
      jsonb '[]' ||
      data.attribute_change2jsonb('system_person_coin', to_jsonb(in_new_value)) ||
      data.attribute_change2jsonb('person_coin', to_jsonb(in_new_value), in_object_id) ||
      data.attribute_change2jsonb('person_coin', to_jsonb(in_new_value), 'master'),
      in_actor_id,
      in_reason);
  v_diffs :=
    v_diffs ||
    data.change_object(
      data.get_object_id(v_object_code || '_next_statuses'),
      jsonb '[]' ||
      data.attribute_change2jsonb('person_coin', to_jsonb(in_new_value)),
      in_actor_id,
      in_reason);

  return v_diffs;
end;
$$
language plpgsql;

-- drop function pallas_project.change_money(integer, bigint, integer, text);

create or replace function pallas_project.change_money(in_object_id integer, in_new_value bigint, in_actor_id integer, in_reason text)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_changes jsonb :=
    jsonb '[]' ||
    data.attribute_change2jsonb('system_money', to_jsonb(in_new_value));
  v_money_attr_id integer := data.get_attribute_id('money');
  v_value_object_id integer;
  v_diffs jsonb;
begin
  -- Изменяемые объекты: сам объект, его страница покупки статусов (для астеров и марсиан)
  for v_value_object_id in
  (
    select value_object_id
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = v_money_attr_id and
      value_object_id is not null
  )
  loop
    v_changes := v_changes || data.attribute_change2jsonb(v_money_attr_id, to_jsonb(in_new_value), v_value_object_id);
  end loop;

  v_diffs :=
    data.change_object(
      in_object_id,
      v_changes,
      in_actor_id,
      in_reason);

  if data.is_object_exists(v_object_code || '_next_statuses') then
    v_diffs :=
      v_diffs ||
      data.change_object(
        data.get_object_id(v_object_code || '_next_statuses'),
        jsonb '[]' ||
        data.attribute_change2jsonb('money', to_jsonb(in_new_value)),
        in_actor_id,
        in_reason);
  end if;

  return v_diffs;
end;
$$
language plpgsql;

-- drop function pallas_project.change_next_status(integer, text, integer, integer, text);

create or replace function pallas_project.change_next_status(in_object_id integer, in_status_name text, in_new_value integer, in_actor_id integer, in_reason text)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_diffs jsonb;
begin
  -- Изменяемые объекты: сам объект, его страница покупки статусов
  v_diffs :=
    data.change_object(
      in_object_id,
      jsonb '[]' ||
      data.attribute_change2jsonb('system_person_next_' || in_status_name || '_status', to_jsonb(in_new_value)),
      in_actor_id,
      in_reason);
  v_diffs :=
    v_diffs ||
    data.change_object(
      data.get_object_id(v_object_code || '_next_statuses'),
      jsonb '[]' ||
      data.attribute_change2jsonb(in_status_name || '_next_status', to_jsonb(in_new_value)),
      in_actor_id,
      in_reason);

  return v_diffs;
end;
$$
language plpgsql;

-- drop function pallas_project.control_to_org_code(text);

create or replace function pallas_project.control_to_org_code(in_control text)
returns text
immutable
as
$$
begin
  if in_control = 'opa' or in_control = 'administration' then
    return 'org_' || in_control;
  end if;

  assert in_control = 'cartel';
  return 'org_starbucks';
end;
$$
language plpgsql;

-- drop function pallas_project.control_to_text(text);

create or replace function pallas_project.control_to_text(in_control text)
returns text
immutable
as
$$
begin
  if in_control = 'opa' then
    return 'СВП';
  elsif in_control = 'administration' then
    return 'Администрация';
  end if;

  assert in_control = 'cartel';
  return 'Картель';
end;
$$
language plpgsql;

-- drop function pallas_project.create_chat(text, jsonb);

create or replace function pallas_project.create_chat(in_code text, in_attributes jsonb)
returns integer
volatile
as
$$
declare
  v_chat_id  integer;
  v_chat_code text;

  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_chat_is_master boolean := (json.get_string_opt(in_attributes,'system_chat_parent_list', '~') = 'master_chats');
  v_chat_can_invite boolean:= json.get_boolean_opt(in_attributes,'system_chat_can_invite', true);
  v_chat_title text := json.get_string_opt(in_attributes, 'title', '');

  v_content text[];
  v_list_attributes jsonb;
begin
  -- создаём новый чат
  v_chat_id := data.create_object(in_code, in_attributes, 'chat');
  v_chat_code := data.get_object_code(v_chat_id);

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_chat_id, v_is_visible_attribute_id, jsonb 'true', v_chat_id);

   -- Собираем список всех персонажей, кроме тех, кто уже в чате
  v_content := pallas_project.get_chat_possible_persons(v_chat_id, v_chat_is_master);

  v_list_attributes := jsonb_build_array(
    jsonb_build_object('code', 'title', 'value', 'Участники чата ' || v_chat_title),
    jsonb_build_object('code', 'is_visible', 'value', true, 'value_object_id', v_chat_id),
    jsonb_build_object('code', 'chat_person_list_persons', 'value', '')
  );

  if v_chat_can_invite then
    v_list_attributes := v_list_attributes || jsonb_build_array(
      jsonb_build_object('code', 'content', 'value', v_content, 'value_object_code', 'master'),
      jsonb_build_object('code', 'content', 'value', v_content, 'value_object_id', v_chat_id),
      jsonb_build_object('code', 'chat_person_list_content_label', 'value', '-------------------------------
Кого добавляем?', 'value_object_code', 'master'),
      jsonb_build_object('code', 'chat_person_list_content_label', 'value', '-------------------------------
Кого добавляем?', 'value_object_id', v_chat_id)
    );
  elsif not v_chat_is_master then
    v_list_attributes := v_list_attributes || jsonb_build_array(
      jsonb_build_object('code', 'content', 'value', v_content, 'value_object_code', 'master'),
      jsonb_build_object('code', 'chat_person_list_content_label', 'value', '-------------------------------
Кого добавляем?', 'value_object_code', 'master')
    );
  end if;

  perform data.create_object( v_chat_code || '_person_list', v_list_attributes, 'chat_person_list');

  return v_chat_id;
end;
$$
language plpgsql;

-- drop function pallas_project.create_organization(text, jsonb);

create or replace function pallas_project.create_organization(in_object_code text, in_attributes jsonb)
returns void
volatile
as
$$
-- Не для использования на игре, т.к. обновляет атрибуты напрямую, без уведомлений и блокировок!
declare
  v_master_group_id integer := data.get_object_id('master');
  v_org_id integer := data.create_object(in_object_code, in_attributes, 'organization');
  v_head_group_id integer := data.create_object(in_object_code || '_head', jsonb '{}');
  v_economist_group_id integer := data.create_object(in_object_code || '_economist', jsonb '{}');
  v_auditor_group_id integer := data.create_object(in_object_code || '_auditor', jsonb '{}');
  v_temporary_auditor_group_id integer := data.create_object(in_object_code || '_temporary_auditor', jsonb '{}');
  v_money jsonb := data.get_attribute_value(v_org_id, 'system_money');
  v_org_tax jsonb := data.get_attribute_value(v_org_id, 'system_org_tax');
  v_org_next_tax jsonb;
  v_org_districts_control jsonb;
  v_org_districts_influence jsonb;
  v_org_current_tax_sum jsonb;
  v_org_economics_type jsonb := data.get_attribute_value(v_org_id, 'system_org_economics_type');
  v_value jsonb;
begin
  perform json.get_bigint(v_money);
  assert json.get_string(v_org_economics_type) in ('normal', 'budget', 'profit');

  -- Перекладываем деньги
  perform data.set_attribute_value(v_org_id, 'money', v_money, v_master_group_id);
  perform data.set_attribute_value(v_org_id, 'money', v_money, v_head_group_id);
  perform data.set_attribute_value(v_org_id, 'money', v_money, v_economist_group_id);
  perform data.set_attribute_value(v_org_id, 'money', v_money, v_auditor_group_id);
  perform data.set_attribute_value(v_org_id, 'money', v_money, v_temporary_auditor_group_id);

  if v_org_tax is not null then
    v_org_next_tax := data.get_attribute_value(v_org_id, 'system_org_next_tax');
    v_org_districts_control := data.get_attribute_value(v_org_id, 'system_org_districts_control');
    v_org_districts_influence := data.get_attribute_value(v_org_id, 'system_org_districts_influence');
    v_org_current_tax_sum := data.get_attribute_value(v_org_id, 'system_org_current_tax_sum');

    perform json.get_integer(v_org_tax);
    perform json.get_integer(v_org_next_tax);
    assert json.is_string_array(v_org_districts_control);
    perform json.get_object(v_org_districts_influence);
    perform json.get_bigint(v_org_current_tax_sum);

    -- Заполняем ставки налога
    perform data.set_attribute_value(v_org_id, 'org_tax', v_org_tax, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'org_tax', v_org_tax, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'org_tax', v_org_tax, v_economist_group_id);

    perform data.set_attribute_value(v_org_id, 'org_next_tax', v_org_next_tax, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'org_next_tax', v_org_next_tax, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'org_next_tax', v_org_next_tax, v_economist_group_id);

    -- Заполняем контроль и влияние
    perform data.set_attribute_value(v_org_id, 'org_districts_control', v_org_districts_control, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'org_districts_control', v_org_districts_control, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'org_districts_control', v_org_districts_control, v_economist_group_id);

    perform data.set_attribute_value(v_org_id, 'org_districts_influence', v_org_districts_influence, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'org_districts_influence', v_org_districts_influence, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'org_districts_influence', v_org_districts_influence, v_economist_group_id);

    -- Заполняем накопленные налоги
    perform data.set_attribute_value(v_org_id, 'org_current_tax_sum', v_org_current_tax_sum, v_master_group_id);
  end if;

  perform data.set_attribute_value(v_org_id, 'org_economics_type', v_org_economics_type, v_master_group_id);

  if v_org_economics_type = jsonb '"budget"' then
    v_value := data.get_attribute_value(v_org_id, 'system_org_budget');
    perform json.get_integer(v_value);

    perform data.set_attribute_value(v_org_id, 'org_budget', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'org_budget', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'org_budget', v_value, v_economist_group_id);
  elsif v_org_economics_type = jsonb '"profit"' then
    v_value := data.get_attribute_value(v_org_id, 'system_org_profit');
    perform json.get_integer(v_value);

    perform data.set_attribute_value(v_org_id, 'org_profit', v_value, v_master_group_id);
    perform data.set_attribute_value(v_org_id, 'org_profit', v_value, v_head_group_id);
    perform data.set_attribute_value(v_org_id, 'org_profit', v_value, v_economist_group_id);
  end if;

  -- Создадим страницу с историей транзакций
  perform data.create_object(
    in_object_code || '_transactions',
    format(
      '[
        {"code": "title", "value": "%s"},
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "content", "value": []}
      ]',
      format('История транзакций, %s', json.get_string(data.get_attribute_value(v_org_id, 'title'))),
      v_head_group_id,
      v_economist_group_id,
      v_auditor_group_id,
      v_temporary_auditor_group_id,
      v_master_group_id)::jsonb,
    'transactions');
end;
$$
language plpgsql;

-- drop function pallas_project.create_person(text, text, jsonb, text[]);

create or replace function pallas_project.create_person(in_person_code text, in_login_code text, in_attributes jsonb, in_groups text[])
returns void
volatile
as
$$
-- Не для использования на игре, т.к. обновляет атрибуты напрямую, без уведомлений и блокировок!
declare
  v_person_id integer := data.create_object(in_person_code, in_attributes, 'person', in_groups);
  v_person_code text := data.get_object_code(v_person_id);
  v_login_id integer;
  v_master_group_id integer := data.get_object_id('master');
  v_economy_type jsonb := data.get_attribute_value(v_person_id, 'system_person_economy_type');
  v_attributes jsonb;
begin
  insert into data.logins(code) values(in_login_code) returning id into v_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_login_id, v_person_id);

  perform data.set_attribute_value(v_person_id, 'system_person_notification_count', jsonb '0');

  if v_economy_type is not null then
    declare
      v_cycle integer;
      v_money jsonb;
      v_deposit_money jsonb;
      v_coin jsonb;
    begin
      perform data.set_attribute_value(v_person_id, 'person_economy_type', v_economy_type, v_master_group_id);

      v_cycle := data.get_integer_param('economic_cycle_number');

      -- Переложим суммы остатков
      if v_economy_type != jsonb '"un"' and v_economy_type != jsonb '"fixed"' then
        v_money := data.get_attribute_value(v_person_id, 'system_money');
        perform json.get_integer(v_money);

        perform data.set_attribute_value(v_person_id, 'money', v_money, v_person_id);
        perform data.set_attribute_value(v_person_id, 'money', v_money, v_master_group_id);
      end if;

      if v_economy_type = jsonb '"asters"' then
        v_deposit_money := data.get_attribute_value(v_person_id, 'system_person_deposit_money');
        perform json.get_integer(v_deposit_money);

        perform data.set_attribute_value(v_person_id, 'person_deposit_money', v_deposit_money, v_person_id);
        perform data.set_attribute_value(v_person_id, 'person_deposit_money', v_deposit_money, v_master_group_id);
      end if;

      if v_economy_type = jsonb '"un"' then
        v_coin := data.get_attribute_value(v_person_id, 'system_person_coin');
        perform json.get_integer(v_coin);

        perform data.set_attribute_value(v_person_id, 'person_coin', v_coin, v_person_id);
        perform data.set_attribute_value(v_person_id, 'person_coin', v_coin, v_master_group_id);
      end if;

      -- Заполним будущие статусы
      if v_economy_type != jsonb '"fixed"' then
        perform data.set_attribute_value(v_person_id, 'system_person_next_life_support_status', jsonb '1');
        perform data.set_attribute_value(v_person_id, 'system_person_next_health_care_status', jsonb '0');
        perform data.set_attribute_value(v_person_id, 'system_person_next_recreation_status', jsonb '0');
        perform data.set_attribute_value(v_person_id, 'system_person_next_police_status', jsonb '0');
        perform data.set_attribute_value(v_person_id, 'system_person_next_administrative_services_status', jsonb '0');
      end if;

      -- Создадим страницу для статусов
      perform data.create_object(
        v_person_code || '_statuses',
        format(
          '[
            {"code": "cycle", "value": %s},
            {"code": "is_visible", "value": true, "value_object_id": %s},
            {
              "code": "content",
              "value": [
                "%s_life_support_status_page",
                "%s_health_care_status_page",
                "%s_recreation_status_page",
                "%s_police_status_page",
                "%s_administrative_services_status_page"
              ]
            }
          ]',
          v_cycle,
          v_person_id,
          v_person_code,
          v_person_code,
          v_person_code,
          v_person_code,
          v_person_code)::jsonb,
        'statuses');

      -- И страницы текущих статусов
      perform data.create_object(
        v_person_code || '_life_support_status_page',
        format(
          '[
            {"code": "cycle", "value": %s},
            {"code": "is_visible", "value": true, "value_object_id": %s},
            {"code": "life_support_status", "value": %s}
          ]',
          v_cycle,
          v_person_id,
          json.get_integer(data.get_attribute_value(v_person_id, 'system_person_life_support_status')))::jsonb,
        'life_support_status_page');
      perform data.create_object(
        v_person_code || '_health_care_status_page',
        format(
          '[
            {"code": "cycle", "value": %s},
            {"code": "is_visible", "value": true, "value_object_id": %s},
            {"code": "health_care_status", "value": %s}
          ]',
          v_cycle,
          v_person_id,
          json.get_integer(data.get_attribute_value(v_person_id, 'system_person_health_care_status')))::jsonb,
        'health_care_status_page');
      perform data.create_object(
        v_person_code || '_recreation_status_page',
        format(
          '[
            {"code": "cycle", "value": %s},
            {"code": "is_visible", "value": true, "value_object_id": %s},
            {"code": "recreation_status", "value": %s}
          ]',
          v_cycle,
          v_person_id,
          json.get_integer(data.get_attribute_value(v_person_id, 'system_person_recreation_status')))::jsonb,
        'recreation_status_page');
      perform data.create_object(
        v_person_code || '_police_status_page',
        format(
          '[
            {"code": "cycle", "value": %s},
            {"code": "is_visible", "value": true, "value_object_id": %s},
            {"code": "police_status", "value": %s}
          ]',
          v_cycle,
          v_person_id,
          json.get_integer(data.get_attribute_value(v_person_id, 'system_person_police_status')))::jsonb,
        'police_status_page');
      perform data.create_object(
        v_person_code || '_administrative_services_status_page',
        format(
          '[
            {"code": "cycle", "value": %s},
            {"code": "is_visible", "value": true, "value_object_id": %s},
            {"code": "administrative_services_status", "value": %s}
          ]',
          v_cycle,
          v_person_id,
          json.get_integer(data.get_attribute_value(v_person_id, 'system_person_administrative_services_status')))::jsonb,
        'administrative_services_status_page');

      if v_economy_type != jsonb '"fixed"' then
        -- Создадим страницу для покупки статусов
        v_attributes :=
          format(
            '[
              {"code": "cycle", "value": %s},
              {"code": "is_visible", "value": true, "value_object_id": %s},
              {"code": "life_support_next_status", "value": 1},
              {"code": "health_care_next_status", "value": 0},
              {"code": "recreation_next_status", "value": 0},
              {"code": "police_next_status", "value": 0},
              {"code": "administrative_services_next_status", "value": 0}
            ]',
            v_cycle,
            v_person_id)::jsonb;

        if v_economy_type = jsonb '"un"' then
          v_attributes := v_attributes || data.attribute_change2jsonb('person_coin', data.get_attribute_value(v_person_id, 'system_person_coin'));
        else
          v_attributes := v_attributes || data.attribute_change2jsonb('money', data.get_attribute_value(v_person_id, 'system_money'));
        end if;

        perform data.create_object(
          v_person_code || '_next_statuses',
          v_attributes,
          'next_statuses');

        if v_economy_type != jsonb '"un"' and v_economy_type != jsonb '"fixed"' then
          -- Создадим страницу с историей транзакций
          perform data.create_object(
            v_person_code || '_transactions',
            format(
              '[
                {"code": "is_visible", "value": true, "value_object_id": %s},
                {"code": "content", "value": []}
              ]',
              v_person_id)::jsonb,
            'transactions');
        end if;
      end if;
    end;
  end if;

  -- Обновим район, если есть
  declare
    v_district text := json.get_string_opt(data.get_attribute_value(v_person_id, 'person_district'), null);
    v_district_id integer;
    v_is_person boolean;
    v_content jsonb;
  begin
    if v_district is not null then
      v_district_id := data.get_object_id(v_district);
      v_is_person := pp_utils.is_in_group(v_person_id, 'player');

      if v_is_person then
        select jsonb_agg(o.code order by data.get_attribute_value(o.id, data.get_attribute_id('title')))
        into v_content
        from jsonb_array_elements(data.get_raw_attribute_value(v_district_id, 'content') || to_jsonb(v_person_code)) arr
        join data.objects o on
          o.code = json.get_string(arr.value);

        perform data.set_attribute_value(v_district_id, 'content', v_content, null);
      end if;

      -- Для мастера видны все персонажи
      select jsonb_agg(o.code order by data.get_attribute_value(o.id, data.get_attribute_id('title')))
      into v_content
      from jsonb_array_elements(data.get_raw_attribute_value(v_district_id, 'content', v_master_group_id) || to_jsonb(v_person_code)) arr
      join data.objects o on
        o.code = json.get_string(arr.value);

      perform data.set_attribute_value(v_district_id, 'content', v_content, v_master_group_id);
    end if;
  end;

  -- Создадим "Мои организации"
  perform data.create_object(
    v_person_code || '_my_organizations',
    format(
      '[
        {"code": "is_visible", "value": true, "value_object_id": %s},
        {"code": "content", "value": []}
      ]',
      v_person_id)::jsonb,
    'my_organizations');
end;
$$
language plpgsql;

-- drop function pallas_project.create_synonym(text, jsonb);

create or replace function pallas_project.create_synonym(in_original_object_code text, in_attributes jsonb)
returns void
volatile
as
$$
-- Не для использования на игре, т.к. обновляет атрибуты напрямую, без уведомлений и блокировок!
begin
  perform pallas_project.create_synonym(null, in_original_object_code, in_attributes);
end;
$$
language plpgsql;

-- drop function pallas_project.create_synonym(text, text, jsonb);

create or replace function pallas_project.create_synonym(in_object_code text, in_original_object_code text, in_attributes jsonb)
returns void
volatile
as
$$
-- Не для использования на игре, т.к. обновляет атрибуты напрямую, без уведомлений и блокировок!
declare
  v_object_id integer;
begin
  v_object_id :=
    data.create_object(
      in_object_code,
      in_attributes,
      'organization');
  perform data.set_attribute_value(v_object_id, 'system_org_synonym', to_jsonb(in_original_object_code));
  perform data.set_attribute_value(v_object_id, 'org_synonym', to_jsonb(in_original_object_code), data.get_object_id('master'));
end;
$$
language plpgsql;

-- drop function pallas_project.create_transaction(integer, text, bigint, bigint, bigint, integer, integer, integer[]);

create or replace function pallas_project.create_transaction(in_object_id integer, in_comment text, in_value bigint, in_balance bigint, in_tax bigint, in_second_object_id integer, in_actor_id integer, in_visible_object_ids integer[])
returns void
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_description text;
  v_visible_object_id integer;
  v_attributes jsonb;
  v_transaction_id integer;
  v_second_object_title text;
  v_second_object_code text;
begin
  assert in_comment is not null;
  assert in_value is not null;
  assert in_balance is not null;
  assert in_tax is null or in_tax >= 0 and in_tax <= abs(in_value);

  if in_second_object_id is not null then
    v_second_object_title := json.get_string_opt(data.get_attribute_value(in_second_object_id, 'title'), null);
    if v_second_object_title is not null then
      v_second_object_code := data.get_object_code(in_second_object_id);
    end if;
  end if;

  if in_value < 0 then
    v_description :=
      format(
        E'%s\n%s\n%s%s%s\nБаланс: %s',
        pp_utils.format_date(clock_timestamp()),
        pp_utils.format_money(in_value),
        in_comment,
        (case when v_second_object_title is not null then format(E'\nПолучатель: [%s](babcom:%s)', v_second_object_title, v_second_object_code) else '' end),
        (case when in_tax is not null then format(E'\nНалог: %s\nСумма перевода после налога: %s', pp_utils.format_money(in_tax), pp_utils.format_money(abs(in_value) - in_tax)) else '' end),
        pp_utils.format_money(in_balance));
  else
    v_description :=
      format(
        E'%s\n%s\n%s%s%s\nБаланс: %s',
        pp_utils.format_date(clock_timestamp()),
        '+' || pp_utils.format_money(in_value - coalesce(in_tax, 0)),
        in_comment,
        (case when v_second_object_title is not null then format(E'\nОтправитель: [%s](babcom:%s)', v_second_object_title, v_second_object_code) else '' end),
        (case when in_tax is not null then format(E'\nНалог: %s\nСумма перевода до налога: %s', pp_utils.format_money(in_tax), pp_utils.format_money(in_value)) else '' end),
        pp_utils.format_money(in_balance));
  end if;

  v_attributes :=
    format(
      '[
        {"code": "mini_description", "value": %s}
      ]',
      to_jsonb(v_description)::text)::jsonb;

  for v_visible_object_id in
  (
    select value
    from unnest(in_visible_object_ids) a(value)
  )
  loop
    v_attributes := v_attributes || format('{"code": "is_visible", "value": true, "value_object_id": %s}', v_visible_object_id)::jsonb;
  end loop;

  v_transaction_id :=
    data.create_object(
      null,
      v_attributes,
      'transaction');

  perform pp_utils.list_prepend_and_notify(
    data.get_object_id(v_object_code || '_transactions'),
    data.get_object_code(v_transaction_id),
    null,
    in_actor_id);
end;
$$
language plpgsql;

-- drop function pallas_project.fcard_debatle(integer, integer);

create or replace function pallas_project.fcard_debatle(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_debatle_status text;
  v_debatle_my_vote_attribute_id integer := data.get_attribute_id('debatle_my_vote');
  v_debatle_person1_votes_attribute_id integer := data.get_attribute_id('debatle_person1_votes');
  v_debatle_person2_votes_attribute_id integer := data.get_attribute_id('debatle_person2_votes');

  v_system_debatle_person1_my_vote integer;
  v_system_debatle_person2_my_vote integer;

  v_system_debatle_person1_votes integer;
  v_system_debatle_person2_votes integer;

  v_debatle_person1_bonuses_json jsonb;
  v_debatle_person2_bonuses_json jsonb;

  v_debatle_person1_bonuses integer;
  v_debatle_person2_bonuses integer;

  v_new_title jsonb;
  v_new_person1 jsonb;
  v_new_person2 jsonb;
  v_new_judge jsonb;
  v_new_debatle_my_vote jsonb;
  v_new_debatle_person1_votes jsonb;
  v_new_debatle_person2_votes jsonb;
begin
  perform * from data.objects where id = in_object_id for update;

  v_debatle_status := json.get_string(data.get_attribute_value(in_object_id,'debatle_status'));

  --debatle_my_vote
  if v_debatle_status in ('vote', 'vote_over', 'closed') then
    v_system_debatle_person1_my_vote := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person1_my_vote', in_actor_id), 0);
    v_system_debatle_person2_my_vote := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person2_my_vote', in_actor_id), 0);

    if in_actor_id = v_person1_id 
      or in_actor_id = v_person2_id 
      or in_actor_id = v_judge_id 
      or pp_utils.is_in_group(in_actor_id, 'master') then
      v_new_debatle_my_vote := jsonb '"Вы не можете голосовать"';
    elsif v_system_debatle_person1_my_vote = 0 and v_system_debatle_person2_my_vote = 0 then
      if v_debatle_status = 'vote' then
        v_new_debatle_my_vote := jsonb '"Вы ещё не проголосовали"';
      else
        v_new_debatle_my_vote := jsonb '"Вы не голосовали"';
      end if;
    elsif v_system_debatle_person1_my_vote > 0 then
      v_new_debatle_my_vote := to_jsonb(format('Вы проголосовали за %s', json.get_string_opt(v_new_person1, 'зачинщика')));
    elsif v_system_debatle_person2_my_vote > 0 then
      v_new_debatle_my_vote := to_jsonb(format('Вы проголосовали за %s', json.get_string_opt(v_new_person2, 'оппонента')));
    end if;
    if coalesce(data.get_raw_attribute_value(in_object_id, v_debatle_my_vote_attribute_id, in_actor_id), jsonb '"~~~"') <> coalesce(v_new_debatle_my_vote, jsonb '"~~~"') then
      perform data.set_attribute_value(in_object_id, v_debatle_my_vote_attribute_id, v_new_debatle_my_vote, in_actor_id, in_actor_id);
    end if;

    v_system_debatle_person1_votes := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person1_votes'), 0);
    v_system_debatle_person2_votes := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person2_votes'), 0);

    v_debatle_person1_bonuses_json := data.get_attribute_value(in_object_id, 'debatle_person1_bonuses');
    v_debatle_person2_bonuses_json := data.get_attribute_value(in_object_id, 'debatle_person2_bonuses');

    select coalesce(sum(x.votes), 0) into v_debatle_person1_bonuses from jsonb_to_recordset(v_debatle_person1_bonuses_json) as x(code text, name text, votes int);
    select coalesce(sum(x.votes), 0) into v_debatle_person2_bonuses from jsonb_to_recordset(v_debatle_person2_bonuses_json) as x(code text, name text, votes int);

    v_new_debatle_person1_votes := to_jsonb(format('Количество голосов за %s: %s + %s (от судьи) = %s',
                                                    json.get_string_opt(v_new_person1, 'зачинщика'), 
                                                    v_system_debatle_person1_votes, 
                                                    v_debatle_person1_bonuses, 
                                                    v_system_debatle_person1_votes + v_debatle_person1_bonuses));
    v_new_debatle_person2_votes := to_jsonb(format('Количество голосов за %s: %s + %s (от судьи) = %s', 
                                                    json.get_string_opt(v_new_person2, 'оппонента'), 
                                                    v_system_debatle_person2_votes, 
                                                    v_debatle_person2_bonuses,
                                                    v_system_debatle_person2_votes + v_debatle_person2_bonuses));

    if coalesce(data.get_raw_attribute_value(in_object_id, v_debatle_person1_votes_attribute_id, in_actor_id), jsonb '"~~~"') <> coalesce(v_new_debatle_person1_votes, jsonb '"~~~"') then
      perform data.set_attribute_value(in_object_id, v_debatle_person1_votes_attribute_id, v_new_debatle_person1_votes, in_actor_id, in_actor_id);
    end if;
    if coalesce(data.get_raw_attribute_value(in_object_id, v_debatle_person2_votes_attribute_id, in_actor_id), jsonb '"~~~"') <> coalesce(v_new_debatle_person2_votes, jsonb '"~~~"') then
      perform data.set_attribute_value(in_object_id, v_debatle_person2_votes_attribute_id, v_new_debatle_person2_votes, in_actor_id, in_actor_id);
    end if;
  end if;
  --TODO 
  -- разобрать json с аудиториями и вывести списком через запятую
  -- посчитать стоимость голосования в зависимости от того, кто смотрит (астерам и марсианам по курсу коина, оон-овцам просто 1 коин)
  -- разобрать бонусы и штрафы.показывать только судье, мастерам и участникам (при этом участникам без кнопок изменения)

end;
$$
language plpgsql;

-- drop function pallas_project.get_chat_persons(integer, boolean);

create or replace function pallas_project.get_chat_persons(in_chat_id integer, in_but_masters boolean default false)
returns jsonb
volatile
as
$$
declare
  v_persons jsonb ;
  v_title_attribute_id integer := data.get_attribute_id('title');
begin
-- Список участников чата
-- in_but_masters = true - кроме мастеров
  select jsonb_agg(jsonb_build_object('code', code, 'name', value) order by value) into v_persons
  from (
    select o.code, av.value
    from data.object_objects oo
    left join data.attribute_values av on av.object_id = oo.object_id and av.attribute_id = v_title_attribute_id and av.value_object_id is null
    join data.objects o on oo.object_id = o.id
    where oo.parent_object_id = in_chat_id
      and oo.parent_object_id <> oo.object_id
      and (not coalesce(in_but_masters, false) 
           or oo.object_id not in (select oom.object_id from data.object_objects oom
                                   join data.objects om on om.id = oom.parent_object_id and om.code = 'master'
                                   where oom.parent_object_id <> oom.object_id))
    for share of oo) a;
  return v_persons;
end;
$$
language plpgsql;

-- drop function pallas_project.get_chat_persons_text(integer, boolean);

create or replace function pallas_project.get_chat_persons_text(in_chat_id integer, in_but_masters boolean default false)
returns text
volatile
as
$$
declare
  v_record record;
  v_persons text := '';
begin
-- Список текст со списком участников чата и ссылками
-- in_but_masters = true - кроме мастеров
  for v_record in (select x.code, x.name 
        from jsonb_to_recordset(pallas_project.get_chat_persons(in_chat_id, in_but_masters)) as x(code text, name jsonb)) loop 
        v_persons := v_persons || '
'|| '['||json.get_string(v_record.name)||'](babcom:'||v_record.code||')';
      end loop;
  return v_persons;
end;
$$
language plpgsql;

-- drop function pallas_project.get_chat_possible_persons(integer, boolean);

create or replace function pallas_project.get_chat_possible_persons(in_chat_id integer, in_is_master_chat boolean default false)
returns text[]
volatile
as
$$
declare
  v_content text[];
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_player_id integer := data.get_object_id('player');
  v_master_id  integer := data.get_object_id('master');
  v_all_person_id  integer := data.get_object_id('master');
begin
  assert in_is_master_chat is not null;
  -- Собираем список всех персонажей, кроме тех, кто уже в чате
  -- in_but_masters = true - без мастеров
  select array_agg(code) into v_content
  from (
    select o.code
    from data.object_objects oo
    join data.objects o on o.id = oo.object_id
    left join data.attribute_values av on av.object_id = o.id and av.attribute_id = v_title_attribute_id and av.value_object_id is null
    where (oo.parent_object_id = v_player_id or in_is_master_chat and oo.parent_object_id in (v_master_id, v_all_person_id))
      and oo.object_id not in (oo.parent_object_id)
      and oo.object_id not in (select chat.object_id from data.object_objects chat where chat.parent_object_id = in_chat_id)
    order by av.value
    for share of o) a;

  if v_content is null then
    v_content := array[]::text[];
  end if;

  return v_content;
end;
$$
language plpgsql;

-- drop function pallas_project.get_debatle_target_audience(text[]);

create or replace function pallas_project.get_debatle_target_audience(in_target_audience text[])
returns text
volatile
as
$$
declare
  v_text text := '';
  v_str text;
begin
  for v_str in (select *
                   from unnest(in_target_audience)) loop
    v_text:= v_text || ', ' || json.get_string_opt(data.get_raw_attribute_value_for_share(data.get_object_id(v_str), 'title'), '');
  end loop;

  v_text := trim(v_text, ', ');

  return v_text;
end;
$$
language plpgsql;

-- drop function pallas_project.get_document_participants(jsonb, integer, boolean);

create or replace function pallas_project.get_document_participants(in_document_participants jsonb, in_actor_id integer, in_with_sign_info boolean default false)
returns text
volatile
as
$$
declare
  v_persons text := '';
  v_record record;
begin
  for v_record in (select x.key, 
                          (case 
                            when in_with_sign_info then (case when x.value = 'true' then ' - Есть подпись' else ' - Нет подписи' end) 
                            else '' end) sign
                   from jsonb_each_text(in_document_participants) x) loop
    v_persons:= v_persons || E'\n' || pp_utils.link(v_record.key) || v_record.sign;
  end loop;

  return v_persons;
end;
$$
language plpgsql;

-- drop function pallas_project.get_document_possible_signers(integer);

create or replace function pallas_project.get_document_possible_signers(in_document_id integer)
returns text[]
volatile
as
$$
declare
  v_content text[];
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_player_id integer := data.get_object_id('player');
  v_system_document_participants jsonb := data.get_attribute_value_for_share(in_document_id, 'system_document_participants');
begin
  -- Собираем список всех персонажей, кроме тех, кто уже в списке участников
  select array_agg(o.code order by av.value) into v_content
  from data.object_objects oo
    left join data.objects o on o.id = oo.object_id
    left join data.attribute_values av on av.object_id = o.id and av.attribute_id = v_title_attribute_id and av.value_object_id is null
  where oo.parent_object_id = v_player_id
    and oo.object_id not in (oo.parent_object_id)
    and o.code not in (select x.key from jsonb_each_text(v_system_document_participants) x);

  if v_content is null then
    v_content := array[]::text[];
  end if;

  return v_content;
end;
$$
language plpgsql;

-- drop function pallas_project.get_group_members(text);

create or replace function pallas_project.get_group_members(in_group_code text)
returns integer[]
volatile
as
$$
declare
  v_objects integer[] := array[]::integer[];
  v_group_id integer := data.get_object_id(in_group_code);
begin
-- Список участников группы
  select array_agg(oo.object_id) into v_objects
      from data.object_objects oo
      where oo.parent_object_id = v_group_id
        and oo.parent_object_id <> oo.object_id;
  return v_objects;
end;
$$
language plpgsql;

-- drop function pallas_project.get_groups_members(text[]);

create or replace function pallas_project.get_groups_members(in_group_codes text[])
returns integer[]
volatile
as
$$
declare
  v_objects integer[] := array[]::integer[];
begin
-- Список участников групп без дублирований
  select array_agg(distinct oo.object_id) into v_objects
      from data.object_objects oo
      where oo.parent_object_id in (select data.get_object_id(unnest) from unnest(in_group_codes)) 
        and oo.parent_object_id <> oo.object_id;

  if v_objects is null then
    v_objects := array[]::integer[];
  end if;
  return v_objects;
end;
$$
language plpgsql;

-- drop function pallas_project.get_person_tax_for_share(integer);

create or replace function pallas_project.get_person_tax_for_share(in_person_id integer)
returns jsonb
volatile
as
$$
declare
  v_district_id integer := data.get_object_id(json.get_string(data.get_raw_attribute_value_for_share(in_person_id, 'person_district')));
  v_district_tax integer := json.get_integer(data.get_raw_attribute_value_for_share(v_district_id, 'district_tax'));
begin
  return v_district_tax;
end;
$$
language plpgsql;

-- drop function pallas_project.init();

create or replace function pallas_project.init()
returns void
volatile
as
$$
declare
  v_default_actor_id integer;
  v_default_login_id integer;
begin
  insert into data.attributes(code, description, type, card_type, can_be_overridden) values
  ('description', 'Текстовый блок с развёрнутым описанием объекта, string', 'normal', 'full', true),
  ('mini_description', 'Текстовый блок с коротким описанием объекта, string', 'normal', 'mini', true),
  ('force_object_diff', 'Атрибут для принудительной генерации diff''а, integer', 'hidden', null, false),
  ('system_is_master_object', 'Мастерский персонаж, boolean', 'system', null, false);

  -- Создадим актора по умолчанию
  v_default_actor_id :=
    data.create_object(
      'anonymous',
      jsonb '[
        {"code": "title", "value": "Гость"},
        {"code": "is_visible", "value": true, "value_object_code": "anonymous"},
        {"code": "actions_function", "value": "pallas_project.actgenerator_anonymous"},
        {"code": "template", "value": {"title": "title", "groups": [{"code": "group1", "actions": ["create_random_person"]}]}}
      ]');

  -- Логин по умолчанию
  insert into data.logins default values returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_default_actor_id);

  insert into data.params(code, value, description) values
  ('default_login_id', to_jsonb(v_default_login_id), 'Идентификатор логина по умолчанию'),
  ('images_url', jsonb '"http://localhost:8000/images/"', 'Абсолютный или относительный URL к папке с изображениями, загружаемыми на сервер'),
  ('year', jsonb '2340', 'Год событий игры'),
  ('first_names', to_jsonb(string_to_array('Джон Джек Пол Джордж Билл Кевин Уильям Кристофер Энтони Алекс Джош Томас Фред Филипп Джеймс Брюс Питер Рональд Люк Энди Антонио Итан Сэм Марк Карл Роберт'||
  ' Эльза Лидия Лия Роза Кейт Тесса Рэйчел Амали Шарлотта Эшли София Саманта Элоиз Талия Молли Анна Виктория Мария Натали Келли Ванесса Мишель Элизабет Кимберли Кортни Лоис Сьюзен Эмма', ' ')), 'Список имён'),
  ('last_names', to_jsonb(string_to_array('Янг Коннери Питерс Паркер Уэйн Ли Максуэлл Калвер Кэмерон Альба Сэндерсон Бэйли Блэкшоу Браун Клеменс Хаузер Кендалл Патридж Рой Сойер Стоун Фостер Хэнкс Грегг'||
  ' Флинн Холл Винсон Уайтинг Хасси Хейвуд Стивенс Робинсон Йорк Гудман Махони Гордон Вуд Рид Грэй Тодд Иствуд Брукс Бродер Ховард Смит Нельсон Синклер Мур Тернер Китон Норрис', ' ')), 'Список фамилий');

  -- Также для работы нам понадобится объект меню
  perform data.create_object(
    'menu',
    jsonb '{
      "is_visible": true,
      "actions_function": "pallas_project.actgenerator_menu",
      "force_object_diff": 0,
      "template": {
        "groups": [
          {"code": "menu_notifications", "actions": ["notifications"]},
          {"code": "menu_lottery", "actions": ["lottery"]},
          {"code": "menu_personal", "actions": ["login", "profile", "transactions", "statuses", "next_statuses", "chats", "master_chats", "documents", "my_organizations", "important_notifications"]},
          {"code": "menu_social", "actions": ["all_chats", "debatles"]},
          {"code": "menu_info", "actions": ["persons", "districts", "organizations"]},
          {"code": "menu_logout", "actions": ["logout"]}
        ]
      }
    }');

  -- И пустой список уведомлений
  perform data.create_object(
    'notifications',
    jsonb '{
      "is_visible": true,
      "title": "Уведомления",
      "template": {"title": "title", "groups": [{"code": "group", "actions": ["clear_notifications"]}]},
      "actions_function": "pallas_project.actgenerator_notifications",
      "list_actions_function": "pallas_project.actgenerator_notifications_content",
      "list_element_function": "pallas_project.lef_notifications",
      "content": []
    }');

  -- Создадим объект для страницы 404
  declare
    v_not_found_object_id integer;
  begin
    insert into data.attributes(code, description, type, card_type, value_description_function, can_be_overridden)
    values('not_found_description', 'Текст на странице 404', 'normal', 'full', 'pallas_project.vd_not_found_description', true);

    v_not_found_object_id :=
      data.create_object(
        'not_found',
        jsonb '{
          "type": "not_found",
          "is_visible": true,
          "title": "404",
          "subtitle": "Not found",
          "template": {"title": "title", "subtitle": "subtitle", "groups": [{"code": "general", "attributes": ["not_found_description"]}]},
          "not_found_description": null
        }');

    insert into data.params(code, value, description)
    values('not_found_object_id', to_jsonb(v_not_found_object_id), 'Идентификатор объекта, отображаемого в случае, если актору недоступен какой-то объект (ну или он реально не существует)');
  end;

  insert into data.actions(code, function) values
  ('act_open_object', 'pallas_project.act_open_object'),
  ('login', 'pallas_project.act_login'),
  ('logout', 'pallas_project.act_logout'),
  ('go_back', 'pallas_project.act_go_back'),
  ('create_random_person', 'pallas_project.act_create_random_person'),
  ('remove_notification', 'pallas_project.act_remove_notification'),
  ('clear_notifications', 'pallas_project.act_clear_notifications');

  -- Базовые классы
  perform data.create_class(
    'notification',
    jsonb '{
      "type": "notification",
      "touch_function": "pallas_project.touch_notification",
      "template": {"groups": [{"code": "group", "attributes": ["title"], "actions": ["remove_notification"]}]}
    }');

  perform pallas_project.init_groups();
  perform pallas_project.init_economics();
  perform pallas_project.init_finances();
  perform pallas_project.init_districts();
  perform pallas_project.init_persons();
  perform pallas_project.init_organizations();
  perform pallas_project.init_organization_roles();
  perform pallas_project.init_debatles();
  perform pallas_project.init_messenger();
  perform pallas_project.init_person_list();
  perform pallas_project.init_documents();
  perform pallas_project.init_lottery();
end;
$$
language plpgsql;

-- drop function pallas_project.init_debatles();

create or replace function pallas_project.init_debatles()
returns void
volatile
as
$$
begin
  -- Атрибуты для дебатла
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('debatle_status', 'Статус', null, 'normal', null, 'pallas_project.vd_debatle_status', false),
  ('debatle_person1', 'Зачинщик', null, 'normal', 'full', 'pallas_project.vd_link', false),
  ('debatle_person2', 'Оппонент', null, 'normal', 'full', 'pallas_project.vd_link', false),
  ('debatle_judge', 'Судья', null, 'normal', 'full', 'pallas_project.vd_link', false),
  ('system_debatle_target_audience', null, 'Аудитория дебатла', 'system', null, null, false),
  ('debatle_target_audience', 'Аудитория', null, 'normal', 'full', null, true),
  ('system_debatle_person1_votes', null, 'Количество голосов за первого участника', 'system', null, null, false),
  ('debatle_person1_votes', null, 'Количество голосов за первого участника', 'normal', 'full', null, true),
  ('system_debatle_person2_votes', null, 'Количество голосов за второго участника', 'system', null, null, false),
  ('debatle_person2_votes', null, 'Количество голосов за второго участника', 'normal', 'full', null, true),
  ('debatle_vote_price', 'Стоимость голосования', null, 'normal', 'full', null, true),
  ('debatle_person1_bonuses', 'Штрафы и бонусы зачинщика', null, 'normal', 'full', 'pallas_project.vd_debatle_bonuses', false),
  ('debatle_person2_bonuses', 'Штрафы и бонусы оппонента', null, 'normal', 'full', 'pallas_project.vd_debatle_bonuses', false),
  ('system_debatle_person1_my_vote', null, 'Количество голосов каждого голосующего за первого участника', 'system', null, null, true),
  ('system_debatle_person2_my_vote', null, 'Количество голосов каждого голосующего за второго участника', 'system', null, null, true),
  ('debatle_my_vote', null, 'Уведомление игрока о том, за кого он проголосовал', 'normal', 'full', null, true),
  -- для временных объектов 
  ('debatle_temp_person_list_edited_person', null, 'Редактируемая персона в дебатле', 'normal', 'full', 'pallas_project.vd_debatle_temp_person_list_edited_person', false),
  ('system_debatle_temp_person_list_debatle_id', null, 'Идентификатор дебатла для списка редактирования персон', 'system', null, null, false),
  ('debatle_temp_bonus_list_person', null, 'Персона, которой начисляем бонусы и штрафы', 'normal', 'full', 'pallas_project.vd_debatle_temp_bonus_list_person', false),
  ('system_debatle_temp_bonus_list_debatle_id', null, 'Идентификатор дебатла для списка редактирования бонусов и штрафов', 'system', null, null, false),
  ('debatle_temp_bonus_list_bonuses', 'Уже имеющиеся бонусы и штрафы', 'Уже имеющиеся бонусы и штрафы', 'normal', 'full', 'pallas_project.vd_debatle_bonuses', false),
  ('debatle_bonus_votes', 'Количество голосов' , 'Количество голосов бонуса или штрафа', 'normal', null, null, false);

-- Объект - страница для работы с дебатлами
  perform data.create_object(
  'debatles',
  jsonb '[
    {"code": "title", "value": "Дебатлы"},
    {"code": "is_visible", "value": true},
    {"code": "content", "value": ["debatles_new", "debatles_future", "debatles_current", "debatles_closed", "debatles_all"], "value_object_code": "master"},
    {"code": "content", "value": ["debatles_my", "debatles_future", "debatles_current", "debatles_closed"]},
    {"code": "actions_function", "value": "pallas_project.actgenerator_debatles"},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "groups": []
      }
    },
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [{"code": "debatles_group", "attributes": ["description"], "actions": ["debatle_create"]}]
      }
    }
  ]');

  -- Объект-класс для списка дебатлов
  perform data.create_class(
  'debatle_list',
  jsonb '[
    {"code": "content", "value": []},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "groups": []
      }
    },
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": []
      }
    }
  ]');

  -- Списки дебатлов
  perform data.create_object(
  'debatles_all',
  jsonb '[
    {"code": "title", "value": "Все дебатлы"},
    {"code": "is_visible", "value": true, "value_object_code": "master"}
  ]',
  'debatle_list');

  perform data.create_object(
  'debatles_new',
  jsonb '[
    {"code": "title", "value": "Неподтверждённые дебатлы"},
    {"code": "is_visible", "value": true, "value_object_code": "master"}
  ]',
  'debatle_list');

  perform data.create_object(
  'debatles_my',
  jsonb '[
    {"code": "title", "value": "Мои дебатлы"},
    {"code": "is_visible", "value": true}
  ]',
  'debatle_list');

  perform data.create_object(
  'debatles_future',
  jsonb '[
    {"code": "title", "value": "Будущие дебатлы"},
    {"code": "is_visible", "value": true}
  ]',
  'debatle_list');

  perform data.create_object(
  'debatles_current',
  jsonb '[
    {"code": "title", "value": "Текущие дебатлы"},
    {"code": "is_visible", "value": true}
  ]',
  'debatle_list');

  perform data.create_object(
  'debatles_closed',
  jsonb '[
    {"code": "title", "value": "Завершенные дебатлы"},
    {"code": "is_visible", "value": true}
  ]',
  'debatle_list');

  -- Объект-класс для дебатла
  perform data.create_class(
  'debatle',
  jsonb '[
    {"code": "type", "value": "debatle"},
    {"code": "priority", "value": 97},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "actions_function", "value": "pallas_project.actgenerator_debatle"},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "subtitle": "debatle_status",
        "groups": []
      }
    },
    {
      "code": "template",
      "value": {
      "title": "title",
      "subtitle": "subtitle",
      "groups": [
        {
          "code": "debatle_group1",
          "attributes": ["debatle_theme", "debatle_status", "debatle_person1", "debatle_person2", "debatle_judge", "debatle_target_audience"],
          "actions": [
            "debatle_change_instigator",
            "debatle_change_opponent",
            "debatle_change_judge",
            "debatle_change_theme",
            "debatle_change_subtitle",
            "debatle_change_target_audience"
          ]
        },
        {
          "code": "debatle_group2",
          "actions": [
            "debatle_change_status_new",
            "debatle_change_status_future",
            "debatle_change_status_vote",
            "debatle_change_status_vote_over",
            "debatle_change_status_closed",
            "debatle_change_status_deleted"
          ]
        },
        {
          "code": "debatle_group3",
          "attributes": ["debatle_person1_votes", "debatle_person2_votes", "debatle_vote_price", "debatle_my_vote"],
          "actions": ["debatle_vote_person1", "debatle_vote_person2"]
        },
        {
          "code": "debatle_group4",
          "attributes": ["debatle_person1_bonuses", "debatle_person2_bonuses"],
          "actions": ["debatle_change_bonuses1", "debatle_change_bonuses2"]
        },
        {
          "code": "debatle_group5",
          "actions": ["debatle_chat"]
        }
      ]
    }
    }
  ]');

  -- Объект-класс для аудитории дебатла
  perform data.create_class(
  'debatle_target_audience',
  jsonb '[
    {"code": "type", "value": "debatle_target_audience"},
    {"code": "title", "value": "Изменение аудитории дебатла"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "actions_function", "value": "pallas_project.actgenerator_debatle_target_audience"},
    {"code": "list_actions_function", "value": "pallas_project.actgenerator_debatle_target_audience_content"},
    {"code": "content", "value": ["all_person", "aster", "opa", "cartel"]},
    {
      "code": "template",
      "value": {
        "title": "title",
        "groups": [
          {
            "code": "debatle_target_audience_group1",
            "attributes": ["debatle_target_audience"],
            "actions": ["go_back"]
          }
        ]
      }
    }
  ]');

  -- Объект-класс для временных списков персон для редактирования дебатла
  perform data.create_class(
  'debatle_temp_person_list',
  jsonb '[
    {"code": "content", "value": []},
    {"code": "actions_function", "value": "pallas_project.actgenerator_debatle_temp_person_list"},
    {"code": "list_element_function", "value": "pallas_project.lef_debatle_temp_person_list"},
    {"code": "temporary_object", "value": true},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [
          {
            "code": "group1",
            "actions": ["debatle_change_person_back"]
          },
          {
            "code": "group2",
            "actions": ["debatle_temp_person_list_edited_person"]
          }
        ]
      }
    }
  ]');

  -- Объект-класс для временных списков персон для редактирования бонусов и штрафов
  perform data.create_class(
  'debatle_temp_bonus_list',
  jsonb '[
    {"code": "content", "value": []},
    {"code": "actions_function", "value": "pallas_project.actgenerator_debatle_temp_bonus_list"},
    {"code": "list_element_function", "value": "pallas_project.lef_debatle_temp_bonus_list"},
    {"code": "temporary_object", "value": true},
    {
      "code": "template",
      "value": {
      "title": "title",
      "subtitle": "subtitle",
      "groups": [
        {
          "code": "group1",
          "actions": ["debatle_change_bonus_back"]
        },
        {
          "code": "group2",
          "attributes": ["debatle_temp_bonus_list_bonuses", "debatle_temp_bonus_list_person"],
          "actions": ["debatle_change_other_bonus", "debatle_change_other_fine"]
        }
      ]
    }
    }
  ]');

  -- Объекты для списка изменений бонусов и штрафов
  -- Класс
  perform data.create_class(
  'debatle_bonus',
  jsonb '[
    {"code": "is_visible", "value": true},
    {
      "code": "template",
      "value": {
      "title": "title",
      "groups": [{
          "code": "group1",
          "attributes": ["debatle_bonus_votes"]
        }]
      }
    }
  ]');

  perform data.create_object(
  'debatle_bonus_long',
  jsonb '[
    {"code": "title", "value": "затянутое выступление"},
    {"code": "debatle_bonus_votes", "value": -1}
  ]',
  'debatle_bonus');

  perform data.create_object(
  'debatle_bonus_confused',
  jsonb '[
    {"code": "title", "value": "сумбурное выступление"},
    {"code": "debatle_bonus_votes", "value": -1}
  ]',
  'debatle_bonus');

  perform data.create_object(
  'debatle_bonus_shout',
  jsonb '[
    {"code": "title", "value": "крик"},
    {"code": "debatle_bonus_votes", "value": -1}
  ]',
  'debatle_bonus');

  perform data.create_object(
  'debatle_bonus_asters_words',
  jsonb '[
    {"code": "title", "value": "использование астерского"},
    {"code": "debatle_bonus_votes", "value": 1}
  ]',
  'debatle_bonus');

  perform data.create_object(
  'debatle_bonus_poems',
  jsonb '[
    {"code": "title", "value": "использование стихов"},
    {"code": "debatle_bonus_votes", "value": 1}
  ]',
  'debatle_bonus');

  perform data.create_object(
  'debatle_bonus_rap',
  jsonb '[
    {"code": "title", "value": "использование рэпа"},
    {"code": "debatle_bonus_votes", "value": 1}
  ]',
  'debatle_bonus');

  perform data.create_object(
  'debatle_bonus_support',
  jsonb '[
    {"code": "title", "value": "поддержку аудитории"},
    {"code": "debatle_bonus_votes", "value": 1}
  ]',
  'debatle_bonus');

  insert into data.actions(code, function) values
  ('debatle_create', 'pallas_project.act_debatle_create'),
  ('debatle_change_person', 'pallas_project.act_debatle_change_person'),
  ('debatle_change_theme', 'pallas_project.act_debatle_change_theme'),
  ('debatle_change_status', 'pallas_project.act_debatle_change_status'),
  ('debatle_vote', 'pallas_project.act_debatle_vote'),
  ('debatle_change_bonuses','pallas_project.act_debatle_change_bonuses'),
  ('debatle_change_other_bonus','pallas_project.act_debatle_change_other_bonus'),
  ('debatle_change_subtitle','pallas_project.act_debatle_change_subtitle'),
  ('debatle_change_audience_group','pallas_project.act_debatle_change_audience_group');

end;
$$
language plpgsql;

-- drop function pallas_project.init_districts();

create or replace function pallas_project.init_districts()
returns void
volatile
as
$$
declare
  v_districts jsonb := '[]';
  v_district record;
begin
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('district_control', 'Контроль', null, 'normal', null, 'pallas_project.vd_district_control', false),
  ('district_population', 'Население', null, 'normal', null, null, false),
  ('district_influence', 'Влияние', null, 'normal', null, 'pallas_project.vd_district_influence', false),
  ('district_tax', 'Налоговая ставка', null, 'normal', null, 'pallas_project.vd_percent', false),
  ('system_district_tax_coeff', null, 'Коэффициент, на который умножаются налоговые поступления', 'system', null, null, false);

  -- Класс района
  perform data.create_class(
    'district',
    jsonb '[
      {"code": "is_visible", "value": true},
      {"code": "type", "value": "district"},
      {
        "code": "template",
        "value": {
          "title": "title",
          "groups": [
            {"code": "group", "attributes": ["district_tax", "district_control", "district_influence", "district_population"]}
          ]
        }
      }
    ]');

  -- Районы
  for v_district in
  (
    select
      json.get_string(value, 'sector') sector,
      json.get_number(value, 'coeff') coeff,
      json.get_integer(value, 'population') population,
      json.get_integer(value, 'district_tax') tax,
      json.get_object(value, 'district_influence') influence,
      value->'district_control' control
    from jsonb_array_elements(
      jsonb '[
        {"sector": "A", "coeff": 2.5, "population": 22500, "district_tax": 25, "district_influence": {"opa": 0, "cartel": 0, "administration": 1}, "district_control": "administration"},
        {"sector": "B", "coeff": 5, "population": 45000, "district_tax": 25, "district_influence": {"opa": 0, "cartel": 0, "administration": 1}, "district_control": "administration"},
        {"sector": "C", "coeff": 7.5, "population": 67500, "district_tax": 25, "district_influence": {"opa": 0, "cartel": 0, "administration": 1}, "district_control": "administration"},
        {"sector": "D", "coeff": 12.5, "population": 112500, "district_tax": 10, "district_influence": {"opa": 1, "cartel": 0, "administration": 0}, "district_control": "opa"},
        {"sector": "E", "coeff": 25, "population": 225000, "district_tax": 0, "district_influence": {"opa": 0, "cartel": 0, "administration": 0}, "district_control": null},
        {"sector": "F", "coeff": 12.5, "population": 112500, "district_tax": 10, "district_influence": {"opa": 1, "cartel": 0, "administration": 0}, "district_control": "opa"},
        {"sector": "G", "coeff": 25, "population": 225000, "district_tax": 20, "district_influence": {"opa": 0, "cartel": 1, "administration": 0}, "district_control": "cartel"}
      ]')
  )
  loop
    perform data.create_object(
      'sector_' || v_district.sector,
      format(
        '[
          {"code": "title", "value": "%s"},
          {"code": "system_district_tax_coeff", "value": %s},
          {"code": "district_population", "value": %s},
          {"code": "district_tax", "value": %s},
          {"code": "district_influence", "value": %s},
          {"code": "district_control", "value": %s},
          {"code": "content", "value": []},
          {"code": "content", "value": [], "value_object_code": "master"}
        ]',
        'Сектор ' || v_district.sector,
        v_district.coeff,
        v_district.population,
        v_district.tax,
        v_district.influence::text,
        v_district.control::text)::jsonb,
      'district');

    v_districts := v_districts || to_jsonb('sector_' || v_district.sector);
  end loop;

  -- Список районов
  perform data.create_object(
    'districts',
    format(
      '[
        {"code": "type", "value": "districts"},
        {"code": "is_visible", "value": true},
        {"code": "title", "value": "Районы"},
        {
          "code": "template",
          "value": {
            "title": "title",
            "groups": []
          }
        },
        {
          "code": "content",
          "value": %s
        }
      ]',
      v_districts::text)::jsonb);
end;
$$
language plpgsql;

-- drop function pallas_project.init_documents();

create or replace function pallas_project.init_documents()
returns void
volatile
as
$$
declare

begin
  -- Атрибуты для документов
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('document_category', null, 'Категория документа', 'normal', 'full', 'pallas_project.vd_document_category', false),
  ('document_text', null, 'Текст документа', 'normal', 'full', null, false),
  ('system_document_author', null, 'Автор документа', 'system', null, null, false),
  ('document_author', null, 'Автор документа', 'normal', 'full', null, true),
  ('document_last_edit_time', 'Последнее обновление', 'Дата и время последнего редактирования документа', 'normal', 'full', null, true),
  ('system_document_participants', null, 'Участники, подписывающие документ', 'system', null, null, false),
  ('document_participants', 'Подписи', 'Участники, подписывающие документ', 'normal', 'full', null, false),
  ('document_status', 'Статус', 'Статус документа', 'normal', 'full', 'pallas_project.vd_document_status', false),
  ('system_document_is_my', null, 'Признак, что документ в моих списках', 'system', null, null, true),
  -- для дополнительных
  ('system_document_temp_share_list', null, 'Список кодов тех, с кем поделиться', 'system', null, null, false),
  ('document_temp_share_list', 'Поделиться с', 'Список персонажей, с которыми хотим поделиться документом', 'normal', 'full', null, false),
  ('system_document_temp_list_document_id', null, 'Идентификатор документа', 'system', null, null, false),
  ('document_signers_list_participants', 'Участники', 'Участники, подписывающие документ', 'normal', 'full', null, false);

  -- Объекты для категорий документов
  perform data.create_object(
  'rules_documents',
  jsonb '[
    {"code": "title", "value": "Правила"},
    {"code": "is_visible", "value": true},
    {"code": "content", "value": []},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "groups": []
      }
    },
    {
      "code": "template",
      "value": {
        "title": "title",
        "groups": []
      }
    }
  ]');

  perform data.create_object(
  'my_documents',
  jsonb '[
    {"code": "title", "value": "Мои документы"},
    {"code": "is_visible", "value": true},
    {"code": "content", "value": []},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "groups": []
      }
    },
    {
      "code": "template",
      "value": {
        "title": "title",
        "groups": []
      }
    }
  ]');

  perform data.create_object(
  'official_documents',
  jsonb '[
    {"code": "title", "value": "Официальные документы"},
    {"code": "is_visible", "value": true},
    {"code": "content", "value": []},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "groups": []
      }
    },
    {
      "code": "template",
      "value": {
        "title": "title",
        "groups": []
      }
    }
  ]');

  perform data.create_object(
  'documents',
  jsonb '[
    {"code": "title", "value": "Документы"},
    {"code": "is_visible", "value": true},
    {"code": "content", "value": ["my_documents", "official_documents", "rules_documents"]},
    {"code": "actions_function", "value": "pallas_project.actgenerator_documents"},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "groups": []
      }
    },
    {
      "code": "template",
      "value": {
        "title": "title",
        "groups": [{"code": "documents_group", "actions": ["document_create"]}]
      }
    }
  ]');

  perform data.create_class(
  'document',
  jsonb '[
    {"code": "type", "value": "document"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "is_visible", "value": true},
    {"code": "priority", "value": 95},
    {"code": "actions_function", "value": "pallas_project.actgenerator_document"},
    {"code": "list_actions_function", "value": "pallas_project.actgenerator_document_content"},
    {"code": "system_document_participants", "value": {}},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "subtitle": "document_status",
        "groups": []
      }
    },
    {
      "code": "template",
      "value": {
        "title": "title",
        "groups": [{"code": "document_group1", "attributes": ["document_category"], "actions": ["document_edit", "document_delete", "document_share_list", "document_add_to_my", "document_make_official", "document_make_rule"]},
                   {"code": "document_group2", "attributes": ["document_text"]},
                   {"code": "document_group3", "attributes": ["document_status", "document_participants", "document_sent_to_sign"], "actions": ["document_add_signers", "document_send_to_sign", "document_sign", "document_back_to_editing"]},
                   {"code": "document_group4", "attributes": ["document_author", "document_last_edit_time"]}]
      }
    }
  ]');

  perform data.create_class(
  'document_temp_share_list',
  jsonb '[
    {"code": "type", "value": "document_temp_share_list"},
    {"code": "temporary_object", "value": true},
    {"code": "list_element_function", "value": "pallas_project.lef_document_temp_share_list"},
    {"code": "actions_function", "value": "pallas_project.actgenerator_document_temp_share_list"},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "groups": []
      }
    },
    {
      "code": "template",
      "value": {
        "title": "title",
        "groups": [{"code": "document_temp_share_list_group1", "attributes": ["document_temp_share_list"]},
                   {"code": "document_temp_share_list_group2", "actions": ["document_share", "go_back"]}]
      }
    }
  ]');

  perform data.create_class(
  'document_signers_list',
  jsonb '[
    {"code": "type", "value": "document_signers_list"},
    {"code": "temporary_object", "value": true},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "list_element_function", "value": "pallas_project.lef_document_signers_list"},
    {"code": "actions_function", "value": "pallas_project.actgenerator_document_signers_list"},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "groups": []
      }
    },
    {
      "code": "template",
      "value": {
        "title": "title",
        "groups": [{"code": "document_temp_share_list_group1", "actions": ["go_back"]},
                   {"code": "document_temp_share_list_group2", "attributes": ["document_signers_list_participants"]}
                  ]
      }
    }
  ]');

  insert into data.actions(code, function) values
  ('document_create', 'pallas_project.act_document_create'),
  ('document_edit', 'pallas_project.act_document_edit'),
  ('document_delete', 'pallas_project.act_document_delete'),
  ('document_share', 'pallas_project.act_document_share'),
  ('document_share_list', 'pallas_project.act_document_share_list'),
  ('document_add_to_my', 'pallas_project.act_document_add_to_my'),
  ('document_make_official', 'pallas_project.act_document_make_official'),
  ('document_send_to_sign', 'pallas_project.act_document_send_to_sign'),
  ('document_sign', 'pallas_project.act_document_sign'),
  ('document_back_to_editing', 'pallas_project.act_document_back_to_editing'),
  ('document_delete_signer', 'pallas_project.act_document_delete_signer'),
  ('document_sign_for_signer', 'pallas_project.act_document_sign_for_signer'),
  ('document_make_rule', 'pallas_project.act_document_make_rule');

end;
$$
language plpgsql;

-- drop function pallas_project.init_economics();

create or replace function pallas_project.init_economics()
returns void
volatile
as
$$
begin
  insert into data.params(code, value) values
  ('economic_cycle_number', jsonb '1'),
  ('coin_price', jsonb '10'),
  ('life_support_status_prices', jsonb '[6, 1, 1]'),
  ('health_care_status_prices', jsonb '[1, 6, 8]'),
  ('recreation_status_prices', jsonb '[2, 4, 4]'),
  ('police_status_prices', jsonb '[1, 5, 6]'),
  ('administrative_services_status_prices', jsonb '[2, 6, 7]'),
  ('base_un_coins', jsonb '12'),
  ('base_un_rating', jsonb '150');

  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('life_support_status', null, 'Описание на странице статуса', 'normal', null, 'pallas_project.vd_life_support_status', false),
  ('health_care_status', null, 'Описание на странице статуса', 'normal', null, 'pallas_project.vd_health_care_status', false),
  ('recreation_status', null, 'Описание на странице статуса', 'normal', null, 'pallas_project.vd_recreation_status', false),
  ('police_status', null, 'Описание на странице статуса', 'normal', null, 'pallas_project.vd_police_status', false),
  ('administrative_services_status', null, 'Описание на странице статуса', 'normal', null, 'pallas_project.vd_administrative_services_status', false),
  ('life_support_next_status', null, 'Статус на странице покупки', 'normal', null, 'pallas_project.vd_status', false),
  ('health_care_next_status', null, 'Статус на странице покупки', 'normal', null, 'pallas_project.vd_status', false),
  ('recreation_next_status', null, 'Статус на странице покупки', 'normal', null, 'pallas_project.vd_status', false),
  ('police_next_status', null, 'Статус на странице покупки', 'normal', null, 'pallas_project.vd_status', false),
  ('administrative_services_next_status', null, 'Статус на странице покупки', 'normal', null, 'pallas_project.vd_status', false),
  ('cycle', null, 'Текущий экономический цикл', 'normal', null, 'pallas_project.vd_cycle', false);

  insert into data.actions(code, function) values
  ('buy_status', 'pallas_project.act_buy_status');

  perform data.create_class(
    'life_support_status_page',
    jsonb '[
      {"code": "title", "value": "Жизнеобеспечение"},
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {
        "code": "mini_card_template",
        "value": {
          "title": "title",
          "groups": [{"code": "status_group", "attributes": ["life_support_status"]}]
        }
      },
      {
        "code": "template",
        "value": {
          "title": "title",
          "subtitle": "cycle",
          "groups": [{"code": "status_group", "attributes": ["life_support_status"]}]
        }
      }
    ]');
  perform data.create_class(
    'health_care_status_page',
    jsonb '[
      {"code": "title", "value": "Медицина"},
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {
        "code": "mini_card_template",
        "value": {
          "title": "title",
          "groups": [{"code": "status_group", "attributes": ["health_care_status"]}]
        }
      },
      {
        "code": "template",
        "value": {
          "title": "title",
          "subtitle": "cycle",
          "groups": [{"code": "status_group", "attributes": ["health_care_status"]}]
        }
      }
    ]');
  perform data.create_class(
    'recreation_status_page',
    jsonb '[
      {"code": "title", "value": "Развлечения"},
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {
        "code": "mini_card_template",
        "value": {
          "title": "title",
          "groups": [{"code": "status_group", "attributes": ["recreation_status"]}]
        }
      },
      {
        "code": "template",
        "value": {
          "title": "title",
          "subtitle": "cycle",
          "groups": [{"code": "status_group", "attributes": ["recreation_status"]}]
        }
      }
    ]');
  perform data.create_class(
    'police_status_page',
    jsonb '[
      {"code": "title", "value": "Полиция"},
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {
        "code": "mini_card_template",
        "value": {
          "title": "title",
          "groups": [{"code": "status_group", "attributes": ["police_status"]}]
        }
      },
      {
        "code": "template",
        "value": {
          "title": "title",
          "subtitle": "cycle",
          "groups": [{"code": "status_group", "attributes": ["police_status"]}]
        }
      }
    ]');
  perform data.create_class(
    'administrative_services_status_page',
    jsonb '[
      {"code": "title", "value": "Административное обслуживание"},
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {
        "code": "mini_card_template",
        "value": {
          "title": "title",
          "groups": [{"code": "status_group", "attributes": ["administrative_services_status"]}]
        }
      },
      {
        "code": "template",
        "value": {
          "title": "title",
          "subtitle": "cycle",
          "groups": [{"code": "status_group", "attributes": ["administrative_services_status"]}]
        }
      }
    ]');

  perform data.create_class(
    'statuses',
    jsonb '[
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {"code": "type", "value": "statuses"},
      {"code": "title", "value": "Статусы"},
      {"code": "template", "value": {"title": "title", "subtitle": "cycle", "groups": []}}
    ]');

  perform data.create_class(
    'next_statuses',
    jsonb '[
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {"code": "title", "value": "Покупка статусов"},
      {"code": "type", "value": "status_shop"},
      {"code": "actions_function", "value": "pallas_project.actgenerator_next_statuses"},
      {
        "code": "template",
        "value": {
          "title": "title",
          "subtitle": "cycle",
          "groups": [
            {"code": "left", "attributes": ["money", "person_coin"]},
            {"name": "Жизнеобеспечение", "code": "life_support", "attributes": ["life_support_next_status"], "actions": ["life_support_silver", "life_support_gold"]},
            {"name": "Медицина", "code": "health_care", "attributes": ["health_care_next_status"], "actions": ["health_care_bronze", "health_care_silver", "health_care_gold"]},
            {"name": "Развлечения", "code": "recreation", "attributes": ["recreation_next_status"], "actions": ["recreation_bronze", "recreation_silver", "recreation_gold"]},
            {"name": "Полиция", "code": "police", "attributes": ["police_next_status"], "actions": ["police_bronze", "police_silver", "police_gold"]},
            {"name": "Административное обслуживание", "code": "administrative_services", "attributes": ["administrative_services_next_status"], "actions": ["administrative_services_bronze", "administrative_services_silver", "administrative_services_gold"]}
          ]
        }
      }
    ]');
end;
$$
language plpgsql;

-- drop function pallas_project.init_finances();

create or replace function pallas_project.init_finances()
returns void
volatile
as
$$
begin
  insert into data.actions(code, function) values
  ('transfer_money', 'pallas_project.act_transfer_money');

  perform data.create_class(
    'transaction',
    jsonb '[
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {
        "code": "mini_card_template",
        "value": {
          "title": "title",
          "groups": [{"code": "group", "attributes": ["mini_description"]}]
        }
      }
    ]');
  perform data.create_class(
    'transactions',
    jsonb '[
      {"code": "title", "value": "История транзакций"},
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {
        "code": "template",
        "value": {
          "title": "title",
          "groups": []
        }
      },
      {"code": "list_element_function", "value": "pallas_project.lef_do_nothing"}
    ]');
end;
$$
language plpgsql;

-- drop function pallas_project.init_groups();

create or replace function pallas_project.init_groups()
returns void
volatile
as
$$
begin
  -- Класс для группы
  perform data.create_class('group',
  jsonb '{"is_visible": true,
    "template": {
      "title": "title",
      "groups": [{"code": "group_group1", "actions": ["debatle_add_audience_group", "debatle_del_audience_group"]}]
      }
    }');

  -- Группы персон
  perform data.create_object('all_person', jsonb '{"priority": 10, "title": "Все"}', 'group');
  perform data.create_object('player', jsonb '{"priority": 15, "title": "Все"}', 'group');
  perform data.create_object('aster', jsonb '{"priority": 20, "title": "Астеры"}', 'group');
  perform data.create_object('un', jsonb '{"priority": 30, "title": "Граждане ООН"}', 'group');
  perform data.create_object('mcr', jsonb '{"priority": 40, "title": "Марсиане"}', 'group');
  perform data.create_object('opa', jsonb '{"priority": 50, "title": "СВП"}', 'group');
  perform data.create_object('cartel', jsonb '{"priority": 60, "title": "Картель"}', 'group');
  perform data.create_object('master', jsonb '{"priority": 190, "title": "Мастера"}', 'group');

end;
$$
language plpgsql;

-- drop function pallas_project.init_lottery();

create or replace function pallas_project.init_lottery()
returns void
volatile
as
$$
declare
  v_object_id integer;
  v_lottery_owner_code text;
begin
  insert into data.params(code, value) values
  ('lottery_ticket_price', jsonb '10');

  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('lottery_ticket_count', 'Количество билетов', 'Количество купленных лотерейных билетов', 'normal', 'full', null, true),
  ('lottery_status', 'Статус', null, 'normal', 'full', 'pallas_project.vd_lottery_status', false),
  ('lottery_winner', 'Победитель', null, 'normal', 'full', 'pallas_project.vd_link', false),
  ('system_lottery_owner', null, 'Человек, завершающий лотерею', 'system', null, null, false);

  insert into data.actions(code, function) values
  ('buy_lottery_ticket', 'pallas_project.act_buy_lottery_ticket'),
  ('finish_lottery', 'pallas_project.act_finish_lottery'),
  ('cancel_lottery', 'pallas_project.act_cancel_lottery');

  select data.get_object_code(object_id)
  into v_lottery_owner_code
  from data.attribute_values
  where
    attribute_id = data.get_attribute_id('title') and
    value = jsonb '"Джерри Адамс"' and
    value_object_id is null;

  v_object_id :=
    data.create_object(
      'lottery',
      format(
        '[
          {"code": "is_visible", "value": true},
          {"code": "title", "value": "Лотерея гражданства ООН"},
          {"code": "type", "value": "lottery"},
          {"code": "lottery_status", "value": "active"},
          {"code": "system_lottery_owner", "value": "%s"},
          {"code": "actions_function", "value": "pallas_project.actgenerator_lottery"},
          {"code": "description", "value": "Все неграждане, присутствующие на астероиде Паллада на момент старта лотереи, официально зарегистрированные и имеющие комм на момент начала лотереи, получают ОДИН билет ЛОТЕРЕИ ГРАЖДАНСТВА совершенно бесплатно.\n\nКаждый негражданин может ДОПОЛНИТЕЛЬНО приобрести ЛЮБОЕ количество билетов лотереи. Стоимость дополнительного билета — UN$10.\n\nПерепродажа и передача билетов ЛОТЕРЕИ ГРАЖДАНСТВА запрещены.\n\nОтказаться от участия в ЛОТЕРЕЕ ГРАЖДАНСТВА нельзя.\n\nОДИН победитель определяется методом случайного выбора между ВСЕМИ (гарантированными и дополнительно приобретенными) билетами ЛОТЕРЕИ ГРАЖДАНСТВА.\n\nЛОТЕРЕЯ ГРАЖДАНСТВА проводится Амандой Ганди, заместителем отдела внутренней ревизии Управления по вопросам космического пространства ООН. Контролёрами ЛОТЕРЕИ ГРАЖДАНСТВА со стороны астероида Паллада назначаются Александра Корсак, главный экономист, и Кара Трейс, военный наблюдатель.\n\nПОБЕДИТЕЛЬ получит официальное уведомление на свой комм сразу же после завершения лотереи, также он будет объявлен в местных и земных новостях.\n\nГражданство может быть отозвано, если выяснится, что награжденный скрывался от правосудия или совершил уголовно наказуемое деяние до победы в лотерее.\n\nФинальный этап состоится на празднике, посвященном юбилею станции, после торжественной речи Аманды Ганди."},
          {
            "code": "template",
            "value": {
              "title": "title",
              "groups": [
                {"code": "tickets", "attributes": ["lottery_status", "lottery_winner", "lottery_ticket_count"], "actions": ["buy_lottery_ticket", "finish_lottery", "cancel_lottery"]},
                {"name": "Правила проведения ЛОТЕРЕИ ГРАЖДАНСТВА", "code": "rules", "attributes": ["description"]}
              ]
            }
          }
        ]',
        v_lottery_owner_code)::jsonb);

  -- Всем астерам добавляем по одному билету
  declare
    v_person_id integer;
  begin
    for v_person_id in
    (
      select oo.object_id
      from data.object_objects oo
      where
        oo.parent_object_id = data.get_object_id('player') and
        oo.parent_object_id != oo.object_id
    )
    loop
      if json.get_string(data.get_attribute_value(v_person_id, 'system_person_economy_type')) = 'asters' then
        perform data.set_attribute_value(v_object_id, data.get_attribute_id('lottery_ticket_count'), jsonb '1', v_person_id);
      end if;
    end loop;
  end;
end;
$$
language plpgsql;

-- drop function pallas_project.init_messenger();

create or replace function pallas_project.init_messenger()
returns void
volatile
as
$$
declare
  v_type_attribute_id integer := data.get_attribute_id('type');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_actions_function_attribute_id integer := data.get_attribute_id('actions_function');
  v_template_attribute_id integer := data.get_attribute_id('template');
  v_full_card_function_attribute_id integer := data.get_attribute_id('full_card_function');
  v_mini_card_function_attribute_id integer := data.get_attribute_id('mini_card_function');
  v_list_element_function_attribute_id integer := data.get_attribute_id('list_element_function');
  v_temporary_object_attribute_id integer := data.get_attribute_id('temporary_object');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_priority_attribute_id integer := data.get_attribute_id('priority');

  v_master_group_id integer := data.get_object_id('master');

  v_chats_id integer;
  v_master_chats_id integer;
  v_chat_class_id integer;
  v_message_class_id integer;
  v_chat_person_list_class_id integer;

  v_system_chat_can_invite_attribute_id integer;
  v_system_chat_can_leave_attribute_id integer;
  v_system_chat_can_mute_attribute_id integer;
  v_system_chat_can_rename_attribute_id integer;
  v_chat_id integer;
begin
  -- Атрибуты 
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  --для сообщений
  ('message_text', null, 'Текст сообщения', 'normal', null, null, false),
  ('system_message_sender', null, 'id объекта-отправителя сообщения', 'system', null, null, false),
  ('system_message_time', null, 'Дата и время отправки сообщения', 'system', null, null, false),
  -- для чатов
  ('system_chat_can_invite', null, 'Возможность пригласить кого-то в чат', 'system', null, null, false),
  ('system_chat_can_leave', null, 'Возможность покинуть чат', 'system', null, null, false),
  ('system_chat_can_mute', null, 'Возможность убрать уведомления о новых сообщениях', 'system', null, null, false),
  ('system_chat_can_rename', null, 'Возможность переименовать чат', 'system', null, null, false),
  ('system_chat_cant_write', null, 'Невозможность писать в чат', 'system', null, null, false),
  ('system_chat_cant_see_members', null, 'Невозможность смотреть список участников', 'system', null, null, false),
  ('chat_is_mute', null, 'Признак отлюченного уведомления о новых сообщениях', 'normal', 'full', 'pallas_project.vd_chat_is_mute', true),
  ('chat_unread_messages', 'Непрочитанных сообщений', 'Количество непрочитанных сообщений', 'normal', 'mini', null, true),
  ('system_chat_length', null , 'Количество сообщений', 'system', null, null, false),
  ('system_chat_is_renamed', null, 'Признак, что чат был переименован', 'system', null, null, false),
  ('system_chat_parent_list', null, 'Список, в котором надо двигать чат вверх', 'system', null, null, false),
    -- для временных объектов для изменения участников
  ('chat_person_list_persons', 'Сейчас участвуют', 'Список участников чата', 'normal', 'full', null, false),
  ('chat_person_list_content_label', null, 'Заголовок списка добавляемых участников', 'normal', null, null, true);

  v_system_chat_can_invite_attribute_id := data.get_attribute_id('system_chat_can_invite');
  v_system_chat_can_leave_attribute_id := data.get_attribute_id('system_chat_can_leave');
  v_system_chat_can_mute_attribute_id := data.get_attribute_id('system_chat_can_mute');
  v_system_chat_can_rename_attribute_id := data.get_attribute_id('system_chat_can_rename');

  -- Объект со списком чатов
  insert into data.objects(code) values('chats') returning id into v_chats_id;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_chats_id, v_type_attribute_id, jsonb '"chats"', null),
  (v_chats_id, v_is_visible_attribute_id, jsonb 'true', null),
  (v_chats_id, v_title_attribute_id, jsonb '"Чаты"', null),
  (v_chats_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_chats"', null),
  (v_chats_id, v_list_element_function_attribute_id, jsonb '"pallas_project.lef_chats"', null),
  (v_chats_id, v_content_attribute_id, jsonb '[]', null),
  (
    v_chats_id,
    v_template_attribute_id,
    jsonb '{
      "title": "title",
      "subtitle": "subtitle",
      "groups": [
        {"code": "chats_group1", "attributes": ["description"], "actions": ["create_chat"]}
      ]
    }',
  null);

  -- Объект со списком всех чатов (для мастеров)
  insert into data.objects(code) values('all_chats') returning id into v_chats_id;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_chats_id, v_type_attribute_id, jsonb '"chats"', null),
  (v_chats_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (v_chats_id, v_title_attribute_id, jsonb '"Все игровые чаты"', null),
  (v_chats_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_chats"', null),
  (v_chats_id, v_list_element_function_attribute_id, jsonb '"pallas_project.lef_chats"', null),
  (v_chats_id, v_content_attribute_id, jsonb '[]', null),
  (
    v_chats_id,
    v_template_attribute_id,
    jsonb '{
      "title": "title",
      "subtitle": "subtitle",
      "groups": [
        {"code": "chats_group1", "attributes": ["description"], "actions": ["create_chat"]}
      ]
    }',
    null
  );

  -- Объект со списком мастерских чатов
  insert into data.objects(code) values('master_chats') returning id into v_master_chats_id;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_master_chats_id, v_type_attribute_id, jsonb '"chats"', null),
  (v_master_chats_id, v_is_visible_attribute_id, jsonb 'true', null),
  (v_master_chats_id, v_title_attribute_id, jsonb '"Общение с мастерами"', null),
  (v_master_chats_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_chats"', null),
  (v_master_chats_id, v_list_element_function_attribute_id, jsonb '"pallas_project.lef_chats"', null),
  (v_master_chats_id, v_content_attribute_id, jsonb '[]', null),
  (
    v_master_chats_id,
    v_template_attribute_id,
    jsonb '{
      "title": "title",
      "subtitle": "subtitle",
      "groups": [
        {"code": "chats_group1", "attributes": ["description"], "actions": ["create_chat"]}
      ]
    }',
    null
  );

  -- Объект-класс для чата
  insert into data.objects(code, type) values('chat', 'class') returning id into v_chat_class_id;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_chat_class_id, v_type_attribute_id, jsonb '"chat"', null),
  (v_chat_class_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (v_chat_class_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_chat"', null),
  (v_chat_class_id, v_list_element_function_attribute_id, jsonb '"pallas_project.lef_do_nothing"', null),
  (v_chat_class_id, v_system_chat_can_invite_attribute_id, jsonb 'true', null),
  (v_chat_class_id, v_system_chat_can_leave_attribute_id, jsonb 'true', null),
  (v_chat_class_id, v_system_chat_can_mute_attribute_id, jsonb 'true', null),
  (v_chat_class_id, v_system_chat_can_rename_attribute_id, jsonb 'true', null),
  (v_chat_class_id, v_priority_attribute_id, jsonb '100', null),
  (
    v_chat_class_id,
    v_template_attribute_id,
    jsonb '{
      "title": "title",
      "subtitle": "subtitle",
      "groups": [
        {
          "code": "chats_group1",
          "attributes": ["chat_is_mute", "chat_unread_messages"],
          "actions": ["chat_add_person", "chat_leave", "chat_mute", "chat_rename", "chat_enter"]
        },
        {
          "code": "chat_group2",
          "name": "Настройки чата",
          "actions": ["chat_change_can_invite", "chat_change_can_leave", "chat_change_can_mute", "chat_change_can_rename"]
        },
        {
          "code": "chat_group3",
          "actions": ["chat_write"]
        }
      ]
    }',
  null);

  -- Объект-класс для сообщения
  insert into data.objects(code, type) values('message', 'class') returning id into v_message_class_id;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_message_class_id, v_type_attribute_id, jsonb '"message"', null),
  (v_message_class_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (
    v_message_class_id,
    v_template_attribute_id,
    jsonb '{
      "groups": [
        {"code": "message_group1", "attributes": ["title", "message_text"]}
      ]
    }',
  null);

  -- Объект-класс для списков персон для редактирования участников чата
  insert into data.objects(code, type) values('chat_person_list', 'class') returning id into v_chat_person_list_class_id;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_chat_person_list_class_id, v_type_attribute_id, jsonb '"chat_person_list"', null),
  (v_chat_person_list_class_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (v_chat_person_list_class_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_chat_temp_person_list"', null),
  (v_chat_person_list_class_id, v_list_element_function_attribute_id, jsonb '"pallas_project.lef_chat_temp_person_list"', null),
  (
    v_chat_person_list_class_id,
    v_template_attribute_id,
    jsonb '{
      "title": "title",
      "subtitle": "subtitle",
      "groups": [
        {"code": "group1", "actions": ["chat_add_person_back"]},
        {"code": "group2", "attributes": ["chat_person_list_persons", "chat_person_list_content_label"]}
      ]
    }', 
  null);

  -- Чат-бот
  perform data.create_object(
  'chat_bot',
  jsonb '{"title": "Чат-бот"}');

  -- Мастерские чаты
  declare
    v_person_id integer;
    v_master_person_id integer;
    v_masters integer[] := pallas_project.get_group_members('master');
    v_important integer;
    v_important_chat_id integer;
    v_redirect_attribute_id integer := data.get_attribute_id('redirect');
  begin
    -- Чат для мастеров и уведомлений
    v_chat_id := pallas_project.create_chat(
    'master_chat',
    jsonb '{
      "content": [],
      "title": "Мастера и уведомления",
      "system_chat_is_renamed": true,
      "system_chat_can_invite": false,
      "system_chat_can_leave": false,
      "system_chat_can_mute": false,
      "system_chat_parent_list": "master_chats"
    }');

    for v_master_person_id in (select * from unnest(v_masters))
    loop
      perform data.add_object_to_object(v_master_person_id, v_chat_id);
    end loop;
    perform pallas_project.change_chat_person_list_on_person(v_chat_id, null, true);

    perform pp_utils.list_prepend_and_notify(v_master_chats_id, data.get_object_code(v_chat_id), v_master_group_id, v_master_group_id);

    -- Чаты для каждого игрового персонажа
    -- Объект для меню "Важные уведомления"
    v_important := data.create_object(
      'important_notifications',
      jsonb_build_object(
        'title', 'Важные уведомления',
        'is_visible', true
      ));
    for v_person_id in (select * from unnest(pallas_project.get_group_members('player')))
    loop
    -- чат с мастерами
      v_chat_id := pallas_project.create_chat(
      null,
      jsonb_build_object(
        'content', jsonb '[]',
        'title', 'Мастерский для ' || json.get_string(data.get_attribute_value(v_person_id, v_title_attribute_id)),
        'system_chat_is_renamed', true,
        'system_chat_can_invite', false,
        'system_chat_can_leave', false,
        'system_chat_can_mute', false,
        'system_chat_can_rename', false,
        'system_chat_parent_list', 'master_chats'
      ));

      perform data.add_object_to_object(v_person_id, v_chat_id);
      for v_master_person_id in (select * from unnest(v_masters))
      loop
        perform data.add_object_to_object(v_master_person_id, v_chat_id);
      end loop;
      perform pallas_project.change_chat_person_list_on_person(v_chat_id, null, true);

      perform pp_utils.list_prepend_and_notify(v_master_chats_id, data.get_object_code(v_chat_id), v_master_group_id, v_master_group_id);
      perform pp_utils.list_prepend_and_notify(v_master_chats_id, data.get_object_code(v_chat_id), v_person_id, v_person_id);

      -- чат для важных уведомлений
      v_important_chat_id := pallas_project.create_chat(
      null,
      jsonb_build_object(
        'content', jsonb '[]',
        'title', 'Важные уведомления',
        'system_chat_is_renamed', true,
        'system_chat_can_invite', false,
        'system_chat_can_leave', false,
        'system_chat_can_mute', false,
        'system_chat_can_rename', false,
        'system_chat_cant_write', true,
        'system_chat_cant_see_members', true
      ));

      insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
      (v_important, v_redirect_attribute_id, to_jsonb(v_important_chat_id), v_person_id);

      perform data.add_object_to_object(v_person_id, v_important_chat_id);
      perform pallas_project.change_chat_person_list_on_person(v_important_chat_id, null, false);
    end loop;
  end;

  insert into data.actions(code, function) values
  ('create_chat', 'pallas_project.act_create_chat'),
  ('chat_write', 'pallas_project.act_chat_write'),
  ('chat_leave','pallas_project.act_chat_leave'),
  ('chat_mute','pallas_project.act_chat_mute'),
  ('chat_rename','pallas_project.act_chat_rename'),
  ('chat_enter','pallas_project.act_chat_enter'),
  ('chat_change_settings','pallas_project.act_chat_change_settings');
end;
$$
language plpgsql;

-- drop function pallas_project.init_organization_roles();

create or replace function pallas_project.init_organization_roles()
returns void
volatile
as
$$
begin
  -- Добавляем персонажей в организации
  perform data.add_object_to_object(data.get_object_id('player1'), data.get_object_id('org_administration_head'));
  perform data.add_object_to_object(data.get_object_id('player2'), data.get_object_id('org_administration_economist'));
  perform data.add_object_to_object(data.get_object_id('player3'), data.get_object_id('org_administration_auditor'));
  perform data.add_object_to_object(data.get_object_id('player4'), data.get_object_id('org_administration_temporary_auditor'));

  perform data.set_attribute_value(data.get_object_id('player1_my_organizations'), 'content', jsonb '["org_administration"]');
  perform data.set_attribute_value(data.get_object_id('player2_my_organizations'), 'content', jsonb '["org_administration"]');
  perform data.set_attribute_value(data.get_object_id('player3_my_organizations'), 'content', jsonb '["org_administration"]');
  perform data.set_attribute_value(data.get_object_id('player4_my_organizations'), 'content', jsonb '["org_administration"]');
end;
$$
language plpgsql;

-- drop function pallas_project.init_organizations();

create or replace function pallas_project.init_organizations()
returns void
volatile
as
$$
declare
  v_district record;
begin
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('system_org_synonym', null, 'Код оригинальной организации, string', 'system', null, null, false),
  ('org_synonym', 'Синоним', null, 'normal', 'full', 'pallas_project.vd_link', true),
  ('system_org_districts_control', null, 'Список кодов районов, которые контролирует организация', 'system', null, null, false),
  ('org_districts_control', 'Контроль', null, 'normal', 'full', 'pallas_project.vd_org_districts_control', true),
  ('system_org_districts_influence', null, 'Может ли организация контролировать районы, string', 'normal', null, null, false),
  ('org_districts_influence', 'Влияние', null, 'normal', 'full', 'pallas_project.vd_org_districts_influence', true),
  ('system_org_economics_type', null, 'Тип экономики (normal, budget, profit)', 'system', null, null, false),
  ('org_economics_type', 'Тип экономики', null, 'normal', 'full', 'pallas_project.vd_org_economics_type', true),
  ('system_org_budget', null, null, 'system', null, null, false),
  ('org_budget', 'Бюджет на следующий цикл', null, 'normal', 'full', 'pallas_project.vd_money', true),
  ('system_org_profit', null, null, 'system', null, null, false),
  ('org_profit', 'Поступления в следующем цикле', null, 'normal', 'full', 'pallas_project.vd_money', true),
  ('system_org_tax', null, null, 'system', null, null, false),
  ('org_tax', 'Текущая налоговая ставка', null, 'normal', 'full', 'pallas_project.vd_percent', true),
  ('system_org_next_tax', null, null, 'system', null, null, false),
  ('org_next_tax', 'Налоговая ставка на следующий цикл', null, 'normal', 'full', 'pallas_project.vd_percent', true),
  ('system_org_current_tax_sum', null, 'Накопленная сумма налогов за текущий цикл', 'system', null, null, false),
  ('org_current_tax_sum', 'Накопленная сумма налогов за текущий цикл', null, 'normal', 'full', 'pallas_project.vd_money', true);

  perform data.create_class(
    'organization',
    jsonb '{
      "type": "organization",
      "is_visible": true,
      "actions_function": "pallas_project.actgenerator_organization",
      "template": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [
          {
            "code": "personal_info",
            "attributes": ["org_synonym", "org_economics_type", "money", "org_budget", "org_profit", "org_tax", "org_next_tax", "org_current_tax_sum", "org_districts_control", "org_districts_influence"],
            "actions": ["transfer_money", "show_transactions"]
          },
          {"code": "info", "attributes": ["description"]}
        ]
      },
      "mini_card_template": {"title": "title", "subtitle": "subtitle", "groups": []}
    }');

  -- Организации
  perform pallas_project.create_organization(
    'org_administration',
    jsonb '{
      "title": "Администрация",
      "system_org_districts_control": ["sector_A", "sector_B", "sector_C"],
      "system_org_districts_influence": {"sector_A": 1, "sector_B": 1, "sector_C": 1, "sector_D": 0, "sector_E": 0, "sector_F": 0, "sector_G": 0},
      "system_org_economics_type": "budget",
      "system_org_budget": 55000,
      "system_money": 55000,
      "system_org_tax": 25,
      "system_org_next_tax": 25,
      "system_org_current_tax_sum": 0
    }');
  perform pallas_project.create_organization(
    'org_opa',
    jsonb '{
      "title": "СВП",
      "system_org_districts_control": ["sector_D", "sector_F"],
      "system_org_districts_influence": {"sector_A": 0, "sector_B": 0, "sector_C": 0, "sector_D": 1, "sector_E": 0, "sector_F": 1, "sector_G": 0},
      "system_org_economics_type": "normal",
      "system_money": 4000,
      "system_org_tax": 10,
      "system_org_next_tax": 10,
      "system_org_current_tax_sum": 0
    }');
  perform pallas_project.create_organization(
    'org_starbucks',
    jsonb '{
      "title": "Starbucks",
      "system_org_districts_control": ["sector_G"],
      "system_org_districts_influence": {"sector_A": 0, "sector_B": 0, "sector_C": 0, "sector_D": 0, "sector_E": 0, "sector_F": 0, "sector_G": 1},
      "system_org_economics_type": "normal",
      "system_money": 2000,
      "system_org_tax": 20,
      "system_org_next_tax": 20,
      "system_org_current_tax_sum": 0
    }');

  perform pallas_project.create_organization(
    'org_de_beers',
    jsonb '{
      "title": "Де Бирс",
      "system_org_economics_type": "budget",
      "system_org_budget": 1380,
      "system_money": 1380
    }');
  perform pallas_project.create_organization(
    'org_akira_sc',
    jsonb '{
      "title": "Akira SC",
      "system_org_economics_type": "budget",
      "system_org_budget": 2000,
      "system_money": 2000
    }');
  perform pallas_project.create_organization(
    'org_clinic',
    jsonb '{
      "title": "Клиника",
      "system_org_economics_type": "budget",
      "system_org_budget": 250,
      "system_money": 250
    }');
  perform pallas_project.create_organization(
    'org_star_helix',
    jsonb '{
      "title": "Star Helix",
      "system_org_economics_type": "budget",
      "system_org_budget": 1300,
      "system_money": 1300
    }');

  perform pallas_project.create_organization(
    'org_teco_mars',
    jsonb '{
      "title": "Теко Марс",
      "system_org_economics_type": "profit",
      "system_org_profit": 1940,
      "system_money": 1940
    }');

  perform pallas_project.create_organization(
    'org_clean_asteroid',
    jsonb '{
      "title": "Чистый астероид",
      "subtitle": "Клининговая компания",
      "system_org_economics_type": "normal",
      "system_money": 0
    }');
  perform pallas_project.create_organization(
    'org_free_sky',
    jsonb '{
      "title": "Свободное небо",
      "system_org_economics_type": "normal",
      "system_money": 3500
    }');
  perform pallas_project.create_organization(
    'org_cherry_orchard',
    jsonb '{
      "title": "Вишнёвый сад",
      "system_org_economics_type": "normal",
      "system_money": 10000
    }');
  perform pallas_project.create_organization(
    'org_tariel',
    jsonb '{
      "title": "Тариэль",
      "subtitle": "Транспортная компания",
      "system_org_economics_type": "normal",
      "system_money": 1000
    }');

  -- Мастерская компания
  perform pallas_project.create_organization(
    'org_white_star',
    jsonb '{
      "title": "White star",
      "subtitle": "IT-компания",
      "system_org_economics_type": "normal",
      "system_money": 0,
      "system_is_master_object": true
    }');

  -- Синонимы
  perform pallas_project.create_synonym(
    'org_starbucks',
    jsonb '{
      "title": "Третий глаз",
      "subtitle": "Салон"
    }');
  perform pallas_project.create_synonym(
    'org_opa',
    jsonb '{
      "title": "Тату-салон"
    }');

  -- Синонимы-поставщики
  -- Лёд
  perform pallas_project.create_synonym(
    'org_aqua_galactic',
    'org_white_star',
    jsonb '{
      "title": "Аква Галактика"
    }');
  perform pallas_project.create_synonym(
    'org_jonny_quick',
    'org_free_sky',
    jsonb '{
      "title": "Джонни Квик"
    }');
  perform pallas_project.create_synonym(
    'org_midnight_diggers',
    'org_starbucks',
    jsonb '{
      "title": "Midnight Diggers"
    }');
  -- Продукты
  perform pallas_project.create_synonym(
    'org_alfa_prime',
    'org_white_star',
    jsonb '{
      "title": "Alfa Prime"
    }');
  perform pallas_project.create_synonym(
    'org_lenin_state_farm',
    'org_opa',
    jsonb '{
      "title": "Совхоз им. Ленина"
    }');
  perform pallas_project.create_synonym(
    'org_ganymede_hydroponical_systems',
    'org_starbucks',
    jsonb '{
      "title": "Гидропонические системы Ганимеда"
    }');
  -- Медикаменты
  perform pallas_project.create_synonym(
    'org_merck',
    'org_white_star',
    jsonb '{
      "title": "Merck"
    }');
  perform pallas_project.create_synonym(
    'org_flora',
    'org_opa',
    jsonb '{
      "title": "Флора Фармасьютикалс"
    }');
  perform pallas_project.create_synonym(
    'org_vector',
    'org_starbucks',
    jsonb '{
      "title": "Вектор"
    }');
  -- Уран
  perform pallas_project.create_synonym(
    'org_westinghouse',
    'org_white_star',
    jsonb '{
      "title": "Westinghouse"
    }');
  perform pallas_project.create_synonym(
    'org_trans_uranium',
    'org_opa',
    jsonb '{
      "title": "TransUranium"
    }');
  perform pallas_project.create_synonym(
    'org_heavy_industries',
    'org_free_sky',
    jsonb '{
      "title": "Heavy Industries Co."
    }');
  -- Метан
  perform pallas_project.create_synonym(
    'org_comet_petroleum',
    'org_white_star',
    jsonb '{
      "title": "Comet Petroleum"
    }');
  perform pallas_project.create_synonym(
    'org_stardust_industries',
    'org_opa',
    jsonb '{
      "title": "Stardust Industries"
    }');
  perform pallas_project.create_synonym(
    'org_pdvsa',
    'org_starbucks',
    jsonb '{
      "title": "PDVSA"
    }');
  -- Товары
  perform pallas_project.create_synonym(
    'org_toom',
    'org_white_star',
    jsonb '{
      "title": "Toom"
    }');
  perform pallas_project.create_synonym(
    'org_amazon',
    'org_opa',
    jsonb '{
      "title": "Amazon.com, Inc."
    }');
  perform pallas_project.create_synonym(
    'org_big_warehouse',
    'org_starbucks',
    jsonb '{
      "title": "Большой Склад"
    }');

  -- Создадим объект со списком организаций
  declare
    v_organization_list jsonb;
    v_class_id integer := data.get_class_id('organization');
  begin
    select jsonb_agg(o.code order by data.get_raw_attribute_value(o.code, 'title'))
    into v_organization_list
    from data.objects o
    where o.class_id = v_class_id;

    perform data.create_object(
      'organizations',
      format(
        '{
          "type": "organization_list",
          "is_visible": true,
          "title": "Все организации",
          "content": %s,
          "template": {
            "title": "title",
            "groups": []
          }
        }',
        v_organization_list::text)::jsonb);
  end;

  -- Лёд: org_aqua_galactic, org_jonny_quick, org_midnight_diggers
  -- Продукты: org_alfa_prime, org_lenin_state_farm, org_ganymede_hydroponical_systems
  -- Медикаменты: org_merck, org_flora, org_vector
  -- Уран: org_westinghouse, org_trans_uranium, org_heavy_industries
  -- Метан: org_comet_petroleum, org_stardust_industries, org_pdvsa
  -- Товары: org_toom, org_amazon, org_big_warehouse

  -- Люди:
  --  org_administration: экономист - Александра Корсак, руководитель - Фрида Фогель
  --  org_opa: Роберт Ли, Лаура Джаррет и Люк Ламбер
  --  org_starbucks: Марк Попов
  --  org_de_beers: Мишон Грей и Абрахам Грей
  --  org_akira_sc: Марк Попов и Роберт Ли
  --  org_clinic: Лина Ковач
  --  org_star_helix: Кайла Ангас
  --  org_teco_mars: Рашид Файзи
  --  org_clean_asteroid: Янг
  --  org_free_sky: мормон
  --  org_cherry_orchard: Александра Корсак
  --  org_tariel: Валентин Штерн

  -- Прочие люди:
  --  Сантьяго Де ла Круз (головной картель)
end;
$$
language plpgsql;

-- drop function pallas_project.init_person_list();

create or replace function pallas_project.init_person_list()
returns void
volatile
as
$$
declare
  v_list jsonb;
  v_master_list jsonb;
begin
  -- Список для игроков
  select jsonb_agg(o.code order by data.get_attribute_value(o.id, 'title'))
  into v_list
  from data.object_objects oo
  join data.objects o on
    o.id = oo.object_id
  where
    oo.parent_object_id = data.get_object_id('player') and
    oo.object_id != oo.parent_object_id;

  -- Список для мастеров
  select jsonb_agg(o.code order by data.get_attribute_value(o.id, 'title'))
  into v_master_list
  from data.object_objects oo
  join data.objects o on
    o.id = oo.object_id
  where
    oo.parent_object_id = data.get_object_id('all_person') and
    oo.object_id != oo.parent_object_id;

  -- Создаём объект
  perform data.create_object(
    'persons',
    jsonb '[
      {"code": "is_visible", "value": true},
      {"code": "type", "value": "persons"},
      {"code": "template", "value": {"title": "title", "groups": []}},
      {"code": "title", "value": "Люди \"Паллады\""}
    ]' ||
    data.attribute_change2jsonb('content', v_list) ||
    data.attribute_change2jsonb('content', v_master_list, 'master'));
end;
$$
language plpgsql;

-- drop function pallas_project.init_persons();

create or replace function pallas_project.init_persons()
returns void
volatile
as
$$
declare
  v_type_attribute_id integer := data.get_attribute_id('type');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_priority_attribute_id integer := data.get_attribute_id('priority');
  v_full_card_function_attribute_id integer := data.get_attribute_id('full_card_function');
  v_mini_card_function_attribute_id integer := data.get_attribute_id('mini_card_function');
  v_actions_function_attribute_id integer := data.get_attribute_id('actions_function');
  v_template_attribute_id integer := data.get_attribute_id('template');
begin
  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden) values
  ('person_occupation', 'Должность', 'normal', null, null, true),
  ('person_state', 'Гражданство', 'normal', 'full', 'pallas_project.vd_person_state', true),
  ('system_money', null, 'system', null, null, false),
  ('money', 'Остаток средств на счёте', 'normal', 'full', 'pallas_project.vd_money', true),
  ('system_person_deposit_money', null, 'system', null, null, false),
  ('person_deposit_money', 'Остаток средств на инвестиционном счёте', 'normal', 'full', 'pallas_project.vd_money', true),
  ('system_person_coin', null, 'system', null, null, false),
  ('person_coin', 'Нераспределённые коины', 'normal', 'full', null, true),
  ('person_opa_rating', 'Популярность среди астеров', 'normal', 'full', 'pallas_project.vd_person_opa_rating', true),
  ('person_un_rating', 'Рейтинг в ООН', 'normal', 'full', null, true),
  ('system_person_economy_type', null, 'system', null, null, false),
  ('person_economy_type', 'Тип экономики', 'normal', 'full', 'pallas_project.vd_person_economy_type', true),
  ('system_person_life_support_status', null, 'system', null, null, false),
  ('person_life_support_status', 'Жизнеобеспечение', 'normal', 'full', 'pallas_project.vd_person_status', true),
  ('system_person_health_care_status', null, 'system', null, null, false),
  ('person_health_care_status', 'Медицина', 'normal', 'full', 'pallas_project.vd_person_status', true),
  ('system_person_recreation_status', null, 'system', null, null, false),
  ('person_recreation_status', 'Развлечения', 'normal', 'full', 'pallas_project.vd_person_status', true),
  ('system_person_police_status', null, 'system', null, null, false),
  ('person_police_status', 'Полиция', 'normal', 'full', 'pallas_project.vd_person_status', true),
  ('system_person_administrative_services_status', null, 'system', null, null, false),
  ('person_administrative_services_status', 'Административное обслуживание', 'normal', 'full', 'pallas_project.vd_person_status', true),
  ('system_person_next_life_support_status', null, 'system', null, null, false),
  ('system_person_next_health_care_status', null, 'system', null, null, false),
  ('system_person_next_recreation_status', null, 'system', null, null, false),
  ('system_person_next_police_status', null, 'system', null, null, false),
  ('system_person_next_administrative_services_status', null, 'system', null, null, false),
  ('system_person_notification_count', null, 'system', null, null, false),
  ('person_district', 'Район проживания', 'normal', 'full', 'pallas_project.vd_link', false);

  -- Объект класса для персон
  perform data.create_class(
    'person',
    jsonb '{
      "type": "person",
      "is_visible": true,
      "priority": 200,
      "actions_function": "pallas_project.actgenerator_person",
      "mini_card_template": {
        "title": "title",
        "groups": [
          {
            "code": "person_mini_document",
            "actions": [
              "document_delete_signer", "document_sign_for_signer"
            ]
          }
        ]
      },
      "template": {
        "title": "title",
        "subtitle": "person_occupation",
        "groups": [
          {
            "code": "person_personal",
            "attributes": [
              "person_economy_type",
              "money",
              "person_deposit_money",
              "person_coin",
              "person_opa_rating",
              "person_un_rating",
              "person_district"
            ],
            "actions": [
              "open_current_statuses",
              "open_next_statuses",
              "open_transactions",
              "transfer_money"
            ]
          },
          {
            "code": "person_statuses",
            "name": "Текущие статусы",
            "attributes": [
              "person_life_support_status",
              "person_health_care_status",
              "person_recreation_status",
              "person_police_status",
              "person_administrative_services_status"
            ]
          },
          {
            "code": "person_public",
            "attributes": [
              "person_state",
              "description"
            ]
          }
        ]
      }
    }');

  -- Класс для личных организаций
  perform data.create_class(
    'my_organizations',
    jsonb '{
      "title": "Мои организации",
      "type": "organization_list",
      "template": {
        "title": "title",
        "groups": []
      }
    }');

  -- Мастера
  perform pallas_project.create_person(null, 'm1', jsonb '{"title": "Саша", "person_occupation": "Мастер"}', array['master']);
  perform pallas_project.create_person(null, 'm2', jsonb '{"title": "Петя", "person_occupation": "Мастер"}', array['master']);
  perform pallas_project.create_person(null, 'm3', jsonb '{"title": "Данил", "person_occupation": "Мастер"}', array['master']);
  perform pallas_project.create_person(null, 'm4', jsonb '{"title": "Нина", "person_occupation": "Мастер"}', array['master']);
  perform pallas_project.create_person(null, 'm5', jsonb '{"title": "Оля", "person_occupation": "Мастер"}', array['master']);
  perform pallas_project.create_person(null, 'm6', jsonb '{"title": "Юра", "person_occupation": "Мастер"}', array['master']);

  -- Игроки
  perform pallas_project.create_person(
    'player1',
    'p1',
    jsonb '{
      "title": "Джерри Адамс",
      "person_occupation": "Секретарь администрации",
      "person_state": "un",
      "system_person_coin": 25,
      "person_opa_rating": 1,
      "person_un_rating": 150,
      "system_person_economy_type": "un",
      "system_person_life_support_status": 3,
      "system_person_health_care_status": 3,
      "system_person_recreation_status": 2,
      "system_person_police_status": 3,
      "system_person_administrative_services_status": 3,
      "person_district": "sector_A"}',
    array['all_person', 'un', 'player']);
  perform pallas_project.create_person(
    'player2',
    'p2',
    jsonb '{
      "title": "Сьюзан Сидорова",
      "person_occupation": "Шахтёр",
      "system_money": 25000,
      "system_person_deposit_money": 100000,
      "person_opa_rating": 5,
      "system_person_economy_type": "asters",
      "system_person_life_support_status": 2,
      "system_person_health_care_status": 1,
      "system_person_recreation_status": 2,
      "system_person_police_status": 1,
      "system_person_administrative_services_status": 1,
      "person_district": "sector_E"}',
    array['all_person', 'opa', 'player', 'aster']);
  perform pallas_project.create_person(
    'player3',
    'p3',
    jsonb '{
      "title": "Чарли Чандрасекар",
      "person_occupation": "Главный экономист",
      "person_state": "un",
      "system_person_coin": 25,
      "person_opa_rating": 1,
      "person_un_rating": 200,
      "system_person_economy_type": "un",
      "system_person_life_support_status": 3,
      "system_person_health_care_status": 3,
      "system_person_recreation_status": 2,
      "system_person_police_status": 3,
      "system_person_administrative_services_status": 3,
      "person_district": "sector_B"}',
    array['all_person', 'un', 'player']);
  perform pallas_project.create_person(
    'player4',
    'p4',
    jsonb '{
      "title": "Алисия Сильверстоун",
      "person_occupation": "Специалист по сейсморазведке",
      "system_money": 25000,
      "system_person_deposit_money": 100000,
      "person_opa_rating": 1,
      "system_person_economy_type": "asters",
      "system_person_life_support_status": 2,
      "system_person_health_care_status": 1,
      "system_person_recreation_status": 2,
      "system_person_police_status": 1,
      "system_person_administrative_services_status": 1,
      "person_district": "sector_D"}',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    null,
    'p5',
    jsonb '{
      "title": "Амели Сноу",
      "person_occupation": "Бригадир грузчиков",
      "system_money": 25000,
      "system_person_deposit_money": 100000,
      "person_opa_rating": 2,
      "system_person_economy_type": "asters",
      "system_person_life_support_status": 2,
      "system_person_health_care_status": 1,
      "system_person_recreation_status": 2,
      "system_person_police_status": 1,
      "system_person_administrative_services_status": 1,
      "person_district": "sector_G"}',
    array['all_person', 'player', 'aster']);

  -- Игротехнические персонажи и тайные личности
  -- Сантьяго де ла Крус - большой картель

  perform pallas_project.create_person(
    null,
    'p10',
    jsonb '{
      "title": "АСС",
      "person_occupation": "Автоматическая система судопроизводства"}',
    array['all_person']);

  perform pallas_project.create_person(
    null,
    'p11',
    jsonb '{
      "title": "Шенг",
      "person_occupation": "Репортёр",
      "system_person_economy_type": "fixed",
      "system_person_life_support_status": 2,
      "system_person_health_care_status": 2,
      "system_person_recreation_status": 2,
      "system_person_police_status": 2,
      "system_person_administrative_services_status": 2,
      "person_district": "sector_D"}',
    array['all_person']);
end;
$$
language plpgsql;

-- drop function pallas_project.lef_chat_temp_person_list(integer, text, integer, integer);

create or replace function pallas_project.lef_chat_temp_person_list(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_chat_code text := replace(data.get_object_code(in_object_id), '_person_list', '');
  v_chat_id integer := data.get_object_id(v_chat_code);

  v_chats_id integer := data.get_object_id('chats');
  v_master_chats_id integer := data.get_object_id('master_chats');

  v_title_attribute_id integer := data.get_attribute_id('title');

  v_chat_is_renamed boolean := json.get_boolean_opt(data.get_attribute_value_for_share(v_chat_id, 'system_chat_is_renamed'), false);
  v_chat_parent_list text := json.get_string_opt(data.get_attribute_value(v_chat_id, 'system_chat_parent_list'), '~');
  v_new_chat_subtitle text := '';
  v_chat_title text;

  v_changes jsonb[];
  v_message_sent boolean;

  v_name record;
  v_names jsonb;
begin
  assert in_request_id is not null;
  assert in_list_object_id is not null;

-- добавляем в группу с рассылкой
  perform data.process_diffs_and_notify(data.change_object_groups(in_list_object_id, array[v_chat_id], array[]::integer[], v_actor_id));

  -- обновляем список текущих персон
  v_names := pallas_project.get_chat_persons(v_chat_id, (v_chat_parent_list <> 'master_chats'));
  for v_name in 
    (select x.name from jsonb_to_recordset(v_names) as x(code text, name jsonb) limit 3) loop 
    v_new_chat_subtitle := v_new_chat_subtitle || ', '|| json.get_string(v_name.name);
   end loop;

  v_new_chat_subtitle := trim(v_new_chat_subtitle, ', ');

  -- Меняем заголовок чата
  v_changes := array[]::jsonb[];
  if not v_chat_is_renamed then 
    v_chat_title := v_new_chat_subtitle;
    v_changes := array_append(v_changes, data.attribute_change2jsonb(v_title_attribute_id, to_jsonb(v_chat_title)));
  else
    v_chat_title := json.get_string_opt(data.get_raw_attribute_value_for_update(v_chat_id, v_title_attribute_id), '');
    v_changes := array_append(v_changes, data.attribute_change2jsonb('subtitle', to_jsonb(v_new_chat_subtitle)));
  end if;
  perform data.change_object_and_notify(v_chat_id, 
                                        to_jsonb(v_changes),
                                        null);

-- Добавляем чат в список чатов в начало
  if v_chat_parent_list = 'master_chats' then
    if not pp_utils.is_in_group(in_list_object_id, 'master') then
      perform pp_utils.list_prepend_and_notify(v_master_chats_id, v_chat_code, in_list_object_id);
    end if;
  elsif v_chat_parent_list = 'chats' then
    perform pp_utils.list_prepend_and_notify(v_chats_id, v_chat_code, in_list_object_id);
  end if;

  -- отправляем нотификацию, что был добавлен в чат
  perform pp_utils.add_notification(in_list_object_id, 'Вы добавлены в чат ' || v_chat_title, v_chat_id);

-- обновляем объект списка
  v_changes := pallas_project.change_chat_person_list_on_person(
    v_chat_id,
    case when not v_chat_is_renamed then v_chat_title else null end,
    (v_chat_parent_list = 'master_chats'),
    true);

  -- рассылаем обновление списка себе
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               in_object_id, 
                                               to_jsonb(v_changes));
  if not v_message_sent then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.lef_chats(integer, text, integer, integer);

create or replace function pallas_project.lef_chats(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_chat_code text := data.get_object_code(in_list_object_id);

  v_chat_unread_messages_attribute_id integer := data.get_attribute_id('chat_unread_messages');
begin
  assert in_request_id is not null;
  assert in_list_object_id is not null;

  perform data.change_object_and_notify(in_list_object_id, 
                                        jsonb_build_array(data.attribute_change2jsonb(v_chat_unread_messages_attribute_id, null, v_actor_id)),
                                        v_actor_id);

  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_chat_code);
end;
$$
language plpgsql;

-- drop function pallas_project.lef_debatle_temp_bonus_list(integer, text, integer, integer);

create or replace function pallas_project.lef_debatle_temp_bonus_list(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_judged_person text := json.get_string(data.get_attribute_value(in_object_id, 'debatle_temp_bonus_list_person'));
  v_debatle_id integer := json.get_integer(data.get_attribute_value(in_object_id, 'system_debatle_temp_bonus_list_debatle_id'));
  v_debatle_code text := data.get_object_code(v_debatle_id);

  v_debatle_person_bonuses jsonb;

  v_bonus_code text;
  v_bonus_name text;
  v_bonus_votes integer;

  v_content text[];

  v_changes jsonb[];
  v_message_sent boolean;
begin
  assert in_request_id is not null;
  assert in_list_object_id is not null;

  if v_judged_person not in ('instigator', 'opponent') then
    perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Ошибка',
      'Непонятно, какой из персон начислять бонусы и штрафы. Наверное что-то пошло не так. Обратитесь к мастеру.'); 
    return;
  end if;

  perform * from data.objects where id = v_debatle_id for update;

  v_bonus_code := data.get_object_code(in_list_object_id);
  v_bonus_name := json.get_string_opt(data.get_attribute_value(in_list_object_id, 'title'), '');
  v_bonus_votes := json.get_integer_opt(data.get_attribute_value(in_list_object_id, 'debatle_bonus_votes'), 1);

  if v_judged_person = 'instigator' then
    v_debatle_person_bonuses := coalesce(data.get_attribute_value(v_debatle_id, 'debatle_person1_bonuses'), jsonb '[]');
    v_debatle_person_bonuses := jsonb_insert(v_debatle_person_bonuses, '{1}', jsonb_build_object('code', v_bonus_code, 'name', v_bonus_name, 'votes', v_bonus_votes));
    v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person1_bonuses', v_debatle_person_bonuses));
  elsif v_judged_person = 'opponent' then
    v_debatle_person_bonuses := coalesce(data.get_attribute_value(v_debatle_id, 'debatle_person2_bonuses'), jsonb '[]');
    v_debatle_person_bonuses := jsonb_insert(v_debatle_person_bonuses, '{1}', jsonb_build_object('code', v_bonus_code, 'name', v_bonus_name, 'votes', v_bonus_votes));
    v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person2_bonuses', v_debatle_person_bonuses));
  end if;

  perform data.change_object_and_notify(v_debatle_id, to_jsonb(v_changes), v_actor_id);

  perform * from data.objects where id = in_object_id for update;

  v_content := json.get_string_array_opt(data.get_attribute_value(in_object_id, 'content', v_actor_id), array[]::text[]);
  v_content := array_remove(v_content, v_bonus_code);

  v_changes := array[]::jsonb[];
  v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_temp_bonus_list_bonuses', v_debatle_person_bonuses));
  v_changes := array_append(v_changes, data.attribute_change2jsonb('content', to_jsonb(v_content)));
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               in_object_id, 
                                               to_jsonb(v_changes));
  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;

end;
$$
language plpgsql;

-- drop function pallas_project.lef_debatle_temp_person_list(integer, text, integer, integer);

create or replace function pallas_project.lef_debatle_temp_person_list(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_edited_person text := json.get_string(data.get_attribute_value_for_share(in_object_id, 'debatle_temp_person_list_edited_person'));
  v_debatle_id integer := json.get_integer(data.get_attribute_value_for_share(in_object_id, 'system_debatle_temp_person_list_debatle_id'));
  v_debatle_code text := data.get_object_code(v_debatle_id);
  v_list_code text := data.get_object_code(in_list_object_id);

  v_debatle_person1 text := json.get_string_opt(data.get_attribute_value_for_update(v_debatle_id, 'debatle_person1'), null);
  v_debatle_person2 text := json.get_string_opt(data.get_attribute_value(v_debatle_id, 'debatle_person2'), null);
  v_debatle_judge integer := json.get_string_opt(data.get_attribute_value(v_debatle_id, 'debatle_judge'), null);
  v_debatle_status text := json.get_string(data.get_attribute_value(v_debatle_id, 'debatle_status'));

  v_old_person text;
  v_old_person_id integer;

  v_debatles_my_id integer := data.get_object_id('debatles_my');

  v_content_attribute_id integer := data.get_attribute_id('content');

  v_content text[];
  v_new_content text[];
  v_changes jsonb[];

  v_change_debatles_my jsonb[]; 
begin
  assert in_request_id is not null;
  assert in_list_object_id is not null;

  if v_edited_person not in ('instigator', 'opponent', 'judge') then
    perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Ошибка', 
      'Непонятно, какую из персон менять. Наверное что-то пошло не так. Обратитесь к мастеру.'); 
    return;
  end if;

  if v_edited_person = 'instigator' then
    v_old_person := v_debatle_person1;
    if v_old_person is distinct from v_list_code then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person1', to_jsonb(v_list_code)));
    end if;
  elsif v_edited_person = 'opponent' then
    v_old_person := v_debatle_person2;
    if v_old_person is distinct from v_list_code then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_person2', to_jsonb(v_list_code)));
    end if;
  elsif v_edited_person = 'judge' then
    v_old_person := v_debatle_judge;
    if v_old_person is distinct from v_list_code then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_judge', to_jsonb(v_list_code)));
    end if;
  end if;

  v_old_person_id := data.get_object_id_opt(v_old_person);

  if v_old_person_id is not null 
  and v_debatle_status not in ('vote', 'vote_over', 'closed') then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', null, v_old_person_id));
  end if;
  if v_edited_person = 'instigator' 
    or (v_edited_person in ('opponent','judge') and v_debatle_status in ('future', 'vote', 'vote_over', 'closed')) then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', jsonb 'true', in_list_object_id));
  end if;
  perform data.change_object_and_notify(v_debatle_id, to_jsonb(v_changes), v_actor_id);

  if v_old_person_id is not null and v_old_person_id <> in_list_object_id then
    --Удаляем из моих дебатлов у старой персоны,
    perform pp_utils.list_remove_and_notify(v_debatles_my_id, v_debatle_code, v_old_person_id);
  end if;
  -- Добавляем в мои дебатлы новой персоне
  perform pp_utils.list_prepend_and_notify(v_debatles_my_id, v_debatle_code, in_list_object_id);

  perform api_utils.create_go_back_action_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;

-- drop function pallas_project.lef_do_nothing(integer, text, integer, integer);

create or replace function pallas_project.lef_do_nothing(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
begin
  assert in_request_id is not null;
  assert in_list_object_id is not null;

  perform api_utils.create_ok_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;

-- drop function pallas_project.lef_document_signers_list(integer, text, integer, integer);

create or replace function pallas_project.lef_document_signers_list(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_document_code text := replace(data.get_object_code(in_object_id), '_signers_list', '');
  v_document_id integer := data.get_object_id(v_document_code);
  v_system_document_participants jsonb;
  v_document_participants text;
  v_document_signers_list_participants text;

  v_list_object_code text := data.get_object_code(in_list_object_id);

  v_changes jsonb[];
  v_message_sent boolean;

  v_document_content text[];
  v_content text[];

  v_name record;
  v_names jsonb;
begin
  assert in_request_id is not null;
  assert in_list_object_id is not null;

  v_system_document_participants := data.get_attribute_value_for_update(v_document_id, 'system_document_participants');
  v_system_document_participants := v_system_document_participants || jsonb_build_object(v_list_object_code, false);

  v_document_participants := pallas_project.get_document_participants(v_system_document_participants, v_actor_id, true);
  v_document_signers_list_participants := pallas_project.get_document_participants(v_system_document_participants, v_actor_id);

  select array_agg(x.key) into v_document_content
    from jsonb_each_text(v_system_document_participants) x ;

  perform data.change_object_and_notify(v_document_id,
                                        jsonb_build_array(
                                          data.attribute_change2jsonb('system_document_participants', v_system_document_participants),
                                          data.attribute_change2jsonb('document_participants', to_jsonb(v_document_participants)),
                                          data.attribute_change2jsonb('content', to_jsonb(v_document_content), in_object_id)
                                        ),
                                        null);

  v_content := pallas_project.get_document_possible_signers(v_document_id);

  -- рассылаем обновление списка себе
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               in_object_id, 
                                               jsonb_build_array(
                                                 data.attribute_change2jsonb('document_signers_list_participants', to_jsonb(v_document_signers_list_participants)),
                                                 data.attribute_change2jsonb('content', to_jsonb(v_content))
                                               ));
  if not v_message_sent then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.lef_document_temp_share_list(integer, text, integer, integer);

create or replace function pallas_project.lef_document_temp_share_list(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_system_document_temp_share_list_attribute_id integer := data.get_attribute_id('system_document_temp_share_list');
  v_system_document_temp_share_list integer[];
  v_document_temp_share_list_attribute_id integer := data.get_attribute_id('document_temp_share_list');
  v_document_temp_share_list text;

  v_content_attribute_id integer := data.get_attribute_id('content');
  v_content text[];

  v_changes jsonb[] := array[]::jsonb[];
  v_message_sent boolean;
begin
  assert in_request_id is not null;
  assert in_list_object_id is not null;

  v_system_document_temp_share_list := json.get_integer_array_opt(data.get_attribute_value_for_update(in_object_id, v_system_document_temp_share_list_attribute_id), array[]::integer[]);
  v_document_temp_share_list := json.get_string_opt(data.get_attribute_value_for_update(in_object_id, v_document_temp_share_list_attribute_id), '');
  v_content := json.get_string_array_opt(data.get_raw_attribute_value_for_update(in_object_id, v_content_attribute_id), array[]::text[]);

  v_system_document_temp_share_list := array_append(v_system_document_temp_share_list, in_list_object_id);
  v_changes := array_append(v_changes, data.attribute_change2jsonb(v_system_document_temp_share_list_attribute_id, to_jsonb(v_system_document_temp_share_list)));

  v_document_temp_share_list := v_document_temp_share_list || E'\n' || json.get_string_opt(data.get_attribute_value(in_list_object_id, 'title'), '');
  v_changes := array_append(v_changes, data.attribute_change2jsonb(v_document_temp_share_list_attribute_id, to_jsonb(v_document_temp_share_list)));

  v_content := array_remove(v_content, data.get_object_code(in_list_object_id));
  v_changes := array_append(v_changes, data.attribute_change2jsonb(v_content_attribute_id, to_jsonb(v_content)));

  -- рассылаем обновление списка себе
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               in_object_id, 
                                               to_jsonb(v_changes));
  if not v_message_sent then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.lef_notifications(integer, text, integer, integer);

create or replace function pallas_project.lef_notifications(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_system_person_notification_count_attr_id integer := data.get_attribute_id('system_person_notification_count');
  v_redirect_object_code text := data.get_object_code(json.get_integer(data.get_raw_attribute_value(in_list_object_id, 'redirect')));
  v_content_attr_id integer := data.get_attribute_id('content');
  v_notifications_count integer := json.get_integer(data.get_attribute_value_for_update(v_actor_id, v_system_person_notification_count_attr_id)) - 1;
  v_content text[] :=
    array_remove(
      json.get_string_array(data.get_raw_attribute_value_for_update(in_object_id, v_content_attr_id, v_actor_id)),
      data.get_object_code(in_list_object_id));
begin
  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_redirect_object_code);

  perform data.set_attribute_value(in_list_object_id, 'is_visible', jsonb 'false', v_actor_id);
  perform data.change_object_and_notify(
    in_object_id,
    jsonb_build_object('content', to_json(v_content)),
    v_actor_id,
    'Open notification');
  perform data.change_object_and_notify(
    v_actor_id,
    jsonb_build_object('system_person_notification_count', v_notifications_count),
    v_actor_id,
    'Open notification');
end;
$$
language plpgsql;

-- drop function pallas_project.notify_transfer_receiver(integer, bigint);

create or replace function pallas_project.notify_transfer_receiver(in_receiver_id integer, in_money bigint)
returns void
volatile
as
$$
declare
  v_receiver_code text := data.get_object_code(in_receiver_id);
  v_type text := json.get_string(data.get_attribute_value(in_receiver_id, 'type'));
  v_transactions_id integer := data.get_object_id(v_receiver_code || '_transactions');
  v_org_person integer;
  v_org_message text;
begin
  if v_type = 'organization' then
    v_org_message :=
      format(
        'Входящий перевод для организации [%s](babcom:%s) на сумму %s',
        json.get_string(data.get_attribute_value(in_receiver_id, 'title')),
        v_receiver_code,
        pp_utils.format_money(in_money));

    for v_org_person in
    (
      select distinct object_id
      from data.object_objects
      where
        parent_object_id in (
          data.get_object_id(v_receiver_code || '_head'),
          data.get_object_id(v_receiver_code || '_economist'),
          data.get_object_id(v_receiver_code || '_auditor'),
          data.get_object_id(v_receiver_code || '_temporary_auditor')) and
        object_id != parent_object_id
    )
    loop
      perform pp_utils.add_notification(
        v_org_person,
        v_org_message,
        v_transactions_id);
    end loop;
  else
    assert v_type = 'person';

    perform pp_utils.add_notification(
      in_receiver_id,
      format('Входящий перевод на сумму %s', pp_utils.format_money(in_money)),
      v_transactions_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.notify_transfer_sender(integer, bigint);

create or replace function pallas_project.notify_transfer_sender(in_sender_id integer, in_money bigint)
returns void
volatile
as
$$
declare
  v_sender_code text := data.get_object_code(in_sender_id);
  v_type text := json.get_string(data.get_attribute_value(in_sender_id, 'type'));
  v_transactions_id integer := data.get_object_id(v_sender_code || '_transactions');
  v_org_person integer;
  v_org_message text;
begin
  if v_type = 'organization' then
    v_org_message :=
      format(
        'Исходящий перевод со счёта организации [%s](babcom:%s) на сумму %s',
        json.get_string(data.get_attribute_value(in_sender_id, 'title')),
        v_sender_code,
        pp_utils.format_money(in_money));

    for v_org_person in
    (
      select distinct object_id
      from data.object_objects
      where
        parent_object_id in (
          data.get_object_id(v_sender_code || '_head'),
          data.get_object_id(v_sender_code || '_economist'),
          data.get_object_id(v_sender_code || '_auditor'),
          data.get_object_id(v_sender_code || '_temporary_auditor')) and
        object_id != parent_object_id
    )
    loop
      perform pp_utils.add_notification(
        v_org_person,
        v_org_message,
        v_transactions_id);
    end loop;
  else
    assert v_type = 'person';

    perform pp_utils.add_notification(
      in_sender_id,
      format('Списана сумма %s', pp_utils.format_money(in_money)),
      v_transactions_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.send_to_important_notifications(integer, text, text);

create or replace function pallas_project.send_to_important_notifications(in_actor_id integer, in_text text, in_object_code text default null::text)
returns void
volatile
as
$$
declare
  v_message_id integer;
  v_message_code text;
  v_message_class_id integer := data.get_class_id('message');

  v_text text;

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_message_text_attribute_id integer := data.get_attribute_id('message_text');
  v_system_message_sender_attribute_id integer := data.get_attribute_id('system_message_sender');
  v_system_message_time_attribute_id integer := data.get_attribute_id('system_message_time');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_important_notifications_id integer := data.get_object_id('important_notifications');
  v_chat_id integer := json.get_integer_opt(data.get_attribute_value(v_important_notifications_id, 'redirect', in_actor_id), null);

  v_chat_bot_id integer := data.get_object_id('chat_bot');
  v_chat_bot_title text := json.get_string(data.get_attribute_value(v_chat_bot_id, v_title_attribute_id));

  v_title text := pp_utils.format_date(clock_timestamp());
  v_object_title text;

  v_content text[];
  v_new_content text[];
  v_changes jsonb[];

  v_system_chat_length_attribute_id integer := data.get_attribute_id('system_chat_length');
  v_chat_length integer;
  v_chat_unread_messages integer;
  v_chat_unread_messages_attribute_id integer := data.get_attribute_id('chat_unread_messages');
begin
  assert v_chat_id is not null;

  if in_object_code is not null then
    v_text := in_text || E'\n\n' || pp_utils.link(in_object_code);
  else
    v_text := in_text;
  end if;
  -- Создаём новое сообщение
  insert into data.objects(class_id) values (v_message_class_id) returning id, code into v_message_id, v_message_code;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_message_id, v_title_attribute_id, to_jsonb(v_title), null),
  (v_message_id, v_message_text_attribute_id, to_jsonb(v_text), null),
  (v_message_id, v_is_visible_attribute_id, jsonb 'true', v_chat_id),
  (v_message_id, v_system_message_sender_attribute_id, to_jsonb(v_chat_bot_id), null),
  (v_message_id, v_system_message_time_attribute_id, to_jsonb(to_char(clock_timestamp(),'DD.MM.YYYY hh24:mi:ss') ), null);

  -- Добавляем сообщение в чат
  perform pp_utils.list_prepend_and_notify(v_chat_id, v_message_code, null, in_actor_id);
end;
$$
language plpgsql;

-- drop function pallas_project.send_to_master_chat(text, text);

create or replace function pallas_project.send_to_master_chat(in_text text, in_object_code text default null::text)
returns void
volatile
as
$$
declare
  v_message_id integer;
  v_message_code text;
  v_message_class_id integer := data.get_class_id('message');

  v_text text;

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_message_text_attribute_id integer := data.get_attribute_id('message_text');
  v_system_message_sender_attribute_id integer := data.get_attribute_id('system_message_sender');
  v_system_message_time_attribute_id integer := data.get_attribute_id('system_message_time');

  v_master_chats_id integer := data.get_object_id('master_chats');
  v_master_chat_id integer := data.get_object_id('master_chat');

  v_master_group_id integer := data.get_object_id('master');

  v_chat_bot_id integer := data.get_object_id('chat_bot');
  v_chat_bot_title text := json.get_string(data.get_attribute_value(v_chat_bot_id, v_title_attribute_id));

  v_title text := pp_utils.format_date(clock_timestamp()) || E'\n' || v_chat_bot_title;

  v_person_id integer;

  v_chat_unread_messages integer;
  v_chat_unread_messages_attribute_id integer := data.get_attribute_id('chat_unread_messages');
begin
  if in_object_code is not null then
    v_text := in_text || ' ' || pp_utils.link(in_object_code);
  else
   v_text := in_text;
  end if;
  -- Создаём новое сообщение
  insert into data.objects(class_id) values (v_message_class_id) returning id, code into v_message_id, v_message_code;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_message_id, v_title_attribute_id, to_jsonb(v_title), null),
  (v_message_id, v_message_text_attribute_id, to_jsonb(v_text), null),
  (v_message_id, v_system_message_sender_attribute_id, to_jsonb(v_chat_bot_id), null),
  (v_message_id, v_system_message_time_attribute_id, to_jsonb(to_char(clock_timestamp(),'DD.MM.YYYY hh24:mi:ss') ), null);

  -- Добавляем сообщение в чат
  perform pp_utils.list_prepend_and_notify(v_master_chat_id, v_message_code, null, v_master_group_id);

  -- Перекладываем этот чат в начало в мастерском списке чатов
  perform pp_utils.list_replace_to_head_and_notify(v_master_chats_id, 'master_chat', v_master_group_id);

  -- Отправляем нотификацию о новом сообщении всем неподписанным на этот чат
  for v_person_id in 
    (select oo.object_id from data.object_objects oo 
     where oo.parent_object_id = v_master_chat_id
       and oo.parent_object_id <> oo.object_id)
  loop
    if not pp_utils.is_actor_subscribed(v_person_id, v_master_chat_id) then
      v_chat_unread_messages := json.get_integer_opt(data.get_raw_attribute_value_for_update(v_master_chat_id, v_chat_unread_messages_attribute_id, v_person_id), 0);
      perform data.change_object_and_notify(v_master_chat_id, 
                                            jsonb_build_array(data.attribute_change2jsonb(v_chat_unread_messages_attribute_id, to_jsonb(v_chat_unread_messages + 1), v_person_id)),
                                            v_person_id);
    end if;
    perform pp_utils.add_notification_if_not_subscribed(v_person_id, 'Мастерский чат: ' || in_text, v_master_chat_id);
  end loop;
end;
$$
language plpgsql;

-- drop function pallas_project.touch_notification(integer, integer);

create or replace function pallas_project.touch_notification(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_notification_code text := data.get_object_code(in_object_id);
  v_system_person_notification_count_attr_id integer := data.get_attribute_id('system_person_notification_count');
  v_content_attr_id integer := data.get_attribute_id('content');
  v_notifications_id integer := data.get_object_id('notifications');
  v_notifications_count integer := json.get_integer(data.get_attribute_value_for_update(in_actor_id, v_system_person_notification_count_attr_id)) - 1;
  v_content text[] :=
    array_remove(
      json.get_string_array(data.get_raw_attribute_value_for_update(v_notifications_id, v_content_attr_id, in_actor_id)),
      v_notification_code);
begin
  perform data.set_attribute_value(in_object_id, 'is_visible', jsonb 'false', in_actor_id);
  perform data.change_object_and_notify(
    in_actor_id,
    jsonb_build_object('system_person_notification_count', v_notifications_count),
    in_actor_id,
    'Touch notification');
  perform data.change_current_object(
    v_notifications_id,
    jsonb '[]' || data.attribute_change2jsonb('content', to_jsonb(v_content), in_actor_id),
    in_actor_id,
    'Touch notification');
end;
$$
language plpgsql;

-- drop function pallas_project.vd_administrative_services_status(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_administrative_services_status(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
stable
as
$$
declare
  v_status integer := json.get_integer(in_value);
begin
  assert v_status in (0, 1, 2, 3);

  if in_card_type = 'mini' then
    if v_status = 0 then
      return 'Нет';
    elsif v_status = 1 then
      return 'Бронзовый';
    elsif v_status = 2 then
      return 'Серебряный';
    else
      return 'Золотой';
    end if;
  else
    if in_value = jsonb '0' then
      return '';
    end if;

    return '![](' || data.get_string_param('images_url') || 'adm_' || (case when v_status = 1 then 'bronze' when v_status = 2 then 'silver' else 'gold' end) || '.svg)';
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_chat_is_mute(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_chat_is_mute(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_bool_value boolean := json.get_boolean_opt(in_value, false);
begin
  case when v_bool_value then
    return 'Уведомления отключены';
  else
    return null;
  end case;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_cycle(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_cycle(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
begin
  return json.get_integer(in_value) || ' цикл';
end;
$$
language plpgsql;

-- drop function pallas_project.vd_debatle_bonuses(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_debatle_bonuses(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := '';
  v_bonuses record;
begin
  for v_bonuses in select x.name, x.votes from jsonb_to_recordset(in_value) as x(code text, name text, votes int) order by x.votes desc, x.name
  loop
    if @ v_bonuses.votes%10 = 1 then
      v_text_value := v_text_value || v_bonuses.votes || ' голос за ' || v_bonuses.name || '
';
    else
      v_text_value := v_text_value || v_bonuses.votes || ' голосов за ' || v_bonuses.name || '
';
    end if;
  end loop;
  if v_text_value <> '' then
    v_text_value := '
' || v_text_value;
  end if;
  return v_text_value;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_debatle_status(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_debatle_status(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'draft' then
    return 'Черновик';
  when v_text_value = 'new' then
    return 'Неподтверждённый';
  when v_text_value = 'future' then
    return 'Будущий';
  when v_text_value = 'vote' then
    return 'Идёт голосование';
  when v_text_value = 'vote_over' then
    return 'Голосование завершено';
  when v_text_value = 'closed' then
    return 'Завершен';
  when v_text_value = 'deleted' then
    return 'Удалён';
  else
    return 'Неизвестно';
  end case;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_debatle_temp_bonus_list_person(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_debatle_temp_bonus_list_person(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'instigator' then
    return 'Выберите бонус или штраф для зачинщика дебатла (первый участник) за';
  when v_text_value = 'opponent' then
    return 'Выберите бонус или штраф для опонента (второй участник) за';
  else
    return 'Что-то пошло не так';
  end case;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_debatle_temp_person_list_edited_person(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_debatle_temp_person_list_edited_person(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'instigator' then
    return 'Выберите зачинщика дебатла';
  when v_text_value = 'opponent' then
    return 'Выберите оппонента для дебатла';
  when v_text_value = 'judge' then
    return 'Выберите судью дебатла';
  else
    return 'Что-то пошло не так';
  end case;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_district_control(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_district_control(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
begin
  assert in_value is not null;
  return case when in_value = jsonb 'null' then 'нет' else pallas_project.control_to_text(json.get_string(in_value)) end;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_district_influence(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_district_influence(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_ret_val text;
begin
  select E'\n' || string_agg(format('%s: %s', title, influence), E'\n')
  into v_ret_val
  from (
    select pallas_project.control_to_text(key) title, json.get_integer(value) influence
    from jsonb_each(in_value)
    order by title) a;

  return v_ret_val; 
end;
$$
language plpgsql;

-- drop function pallas_project.vd_document_category(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_document_category(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'private' then
    return '';
  when v_text_value = 'official' then
    return 'Официальный';
  when v_text_value = 'rule' then
    return 'Правило';
  else
    return 'Неизвестно';
  end case;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_document_status(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_document_status(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'draft' then
    return 'Редактируется';
  when v_text_value = 'signing' then
    return 'Отправлен на подпись';
  when v_text_value = 'signed' then
    return 'Подписан';
  when v_text_value = 'deleted' then
    return 'Удалён';
  else
    return 'Неизвестно';
  end case;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_health_care_status(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_health_care_status(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
stable
as
$$
declare
  v_status integer := json.get_integer(in_value);
begin
  assert v_status in (0, 1, 2, 3);

  if in_card_type = 'mini' then
    if v_status = 0 then
      return 'Нет';
    elsif v_status = 1 then
      return 'Бронзовый';
    elsif v_status = 2 then
      return 'Серебряный';
    else
      return 'Золотой';
    end if;
  else
    if in_value = jsonb '0' then
      return '';
    end if;

    return '![](' || data.get_string_param('images_url') || 'health_' || (case when v_status = 1 then 'bronze' when v_status = 2 then 'silver' else 'gold' end) || '.svg)';
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_life_support_status(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_life_support_status(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
stable
as
$$
declare
  v_status integer := json.get_integer(in_value);
begin
  assert v_status in (0, 1, 2, 3);

  if in_card_type = 'mini' then
    if v_status = 0 then
      return 'Нет';
    elsif v_status = 1 then
      return 'Бронзовый';
    elsif v_status = 2 then
      return 'Серебряный';
    else
      return 'Золотой';
    end if;
  else
    if in_value = jsonb '0' then
      return '';
    end if;

    return '![](' || data.get_string_param('images_url') || 'life_' || (case when v_status = 1 then 'bronze' when v_status = 2 then 'silver' else 'gold' end) || '.svg)';
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_link(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_link(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
stable
as
$$
begin
  return pp_utils.link(json.get_string(in_value));
end;
$$
language plpgsql;

-- drop function pallas_project.vd_lottery_status(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_lottery_status(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
begin
  if in_value = jsonb '"active"' then
    return 'активна';
  elsif in_value = jsonb '"cancelled"' then
    return 'отменена';
  else
    return 'завершена';
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_money(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_money(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
begin
  return pp_utils.format_money(json.get_bigint(in_value));
end;
$$
language plpgsql;

-- drop function pallas_project.vd_not_found_description(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_not_found_description(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_random integer := random.random_integer(1, 12);
begin
  if v_random = 1 then
    return 'Это не те дроиды, которых вы ищете';
  elsif v_random = 2 then
    return 'Эта страница заблокирована по решению Комитета общественной безопасности Марсианской Республики Конгресса';
  elsif v_random = 3 then
    return 'Истина где-то рядом';
  elsif v_random = 4 then
    return 'Большой брат следит за тобой';
  elsif v_random = 5 then
    return 'Добро пожаловать в реальный мир';
  elsif v_random = 6 then
    return 'Не все ли равно, о чем спрашивать, если ответа все равно не получишь, правда?';
  elsif v_random = 7 then
    return 'Мы будем править всей этой землёй, и мы назовём её... Эта Земля.';
  elsif v_random = 8 then
    return 'Ты не пройдёшь!';
  elsif v_random = 9 then
    return 'Принцесса в другом замке!';
  elsif v_random = 10 then
    return 'Торта нет';
  elsif v_random = 11 then
    return 'Ложки не существует';
  end if;

  return 'Меньше значит больше';
end;
$$
language plpgsql;

-- drop function pallas_project.vd_org_districts_control(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_org_districts_control(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_title_attr_id integer := data.get_attribute_id('title');
  v_districts text[] := json.get_string_array(in_value);
  v_description text;
begin
  if coalesce(array_length(v_districts, 1), 0) = 0 then
    return 'нет';
  end if;

  select string_agg(format('[%s](babcom:%s)', title, code), ', ')
  into v_description
  from (
    select code, json.get_string(data.get_attribute_value(id, v_title_attr_id)) title
    from (
      select value code, data.get_object_id(value) id
      from unnest(v_districts) a(value)) d
    order by title) t;

  return v_description; 
end;
$$
language plpgsql;

-- drop function pallas_project.vd_org_districts_influence(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_org_districts_influence(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_title_attr_id integer := data.get_attribute_id('title');
  v_ret_val text;
begin
  select E'\n' || string_agg(format('[%s](babcom:%s): %s', title, code, influence), E'\n')
  into v_ret_val
  from (
    select key code, json.get_string(data.get_attribute_value(key, v_title_attr_id)) title, json.get_integer(value) influence
    from jsonb_each(in_value)
    order by title) a;

  return v_ret_val; 
end;
$$
language plpgsql;

-- drop function pallas_project.vd_org_economics_type(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_org_economics_type(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_economics_type text := json.get_string(in_value);
begin
  assert v_economics_type in ('normal', 'budget', 'profit');

  if v_economics_type = 'normal' then
    return 'Организация без внешнего дохода';
  elsif v_economics_type = 'budget' then
    return 'Организация, счёт которой дополняется до фиксированного бюджета на цикл';
  else
    return 'Организация, получающая фиксированную сумму в цикл';
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_percent(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_percent(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
begin
  return json.get_integer(in_value) || '%';
end;
$$
language plpgsql;

-- drop function pallas_project.vd_person_economy_type(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_person_economy_type(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
begin
  if in_value = jsonb '"un"' then
    return 'ООН — только токены';
  elsif in_value = jsonb '"mcr"' then
    return 'МРК — только текущий счёт';
  elsif in_value = jsonb '"asters"' then
    return 'Астеры — инвестиционный и обнуляемый текущий счета';
  elsif in_value = jsonb '"fixed"' then
    return 'Фиксированные статусы — нет счетов, нет распределения токенов';
  end if;

  assert false;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_person_opa_rating(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_person_opa_rating(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_rating integer := json.get_integer(in_value);
begin
  assert v_rating > 0;

  if v_rating = 1 then
    return 'чувак не шарит';
  elsif v_rating = 2 then
    return 'чувак малёхо шарит';
  elsif v_rating = 3 then
    return 'чувак шарит, но не впиливает';
  elsif v_rating = 4 then
    return 'чувак конкретно шарит!';
  elsif v_rating = 5 then
    return 'чувак нашарил на респект!';
  elsif v_rating = 6 then
    return 'чуваку весь булыжник респектует!';
  end if;

  return 'летит белталода - респект чуваку!';
end;
$$
language plpgsql;

-- drop function pallas_project.vd_person_state(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_person_state(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'un' then
    return 'Гражданин ООН';
  when v_text_value = 'un_base' then
    return 'Догражданин ООН';
  when v_text_value = 'mcr' then
    return 'Гражданин МРК';
  else
    return '';
  end case;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_police_status(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_police_status(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
stable
as
$$
declare
  v_status integer := json.get_integer(in_value);
begin
  assert v_status in (0, 1, 2, 3);

  if in_card_type = 'mini' then
    if v_status = 0 then
      return 'Нет';
    elsif v_status = 1 then
      return 'Бронзовый';
    elsif v_status = 2 then
      return 'Серебряный';
    else
      return 'Золотой';
    end if;
  else
    if in_value = jsonb '0' then
      return '';
    end if;

    return '![](' || data.get_string_param('images_url') || 'police_' || (case when v_status = 1 then 'bronze' when v_status = 2 then 'silver' else 'gold' end) || '.svg)';
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_recreation_status(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_recreation_status(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
stable
as
$$
declare
  v_status integer := json.get_integer(in_value);
begin
  assert v_status in (0, 1, 2, 3);

  if in_card_type = 'mini' then
    if v_status = 0 then
      return 'Нет';
    elsif v_status = 1 then
      return 'Бронзовый';
    elsif v_status = 2 then
      return 'Серебряный';
    else
      return 'Золотой';
    end if;
  else
    if in_value = jsonb '0' then
      return '';
    end if;

    return '![](' || data.get_string_param('images_url') || 'recreation_' || (case when v_status = 1 then 'bronze' when v_status = 2 then 'silver' else 'gold' end) || '.svg)';
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_status(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_status(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_status integer := json.get_integer(in_value);
begin
  assert v_status in (0, 1, 2, 3);

  if v_status = 0 then
    return 'Нет';
  elsif v_status = 1 then
    return 'Бронзовый';
  elsif v_status = 2 then
    return 'Серебряный';
  else
    return 'Золотой';
  end if;
end;
$$
language plpgsql;

-- drop function pp_utils.add_notification(integer, text, integer, boolean);

create or replace function pp_utils.add_notification(in_actor_id integer, in_text text, in_redirect_object integer default null::integer, in_is_important boolean default false)
returns void
volatile
as
$$
declare
  v_notification_code text;
  v_notification_id integer;
  v_object_code text;
  v_notification_title text;

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_redirect_attribute_id integer := data.get_attribute_id('redirect');
  v_system_person_notification_count_attribute_id integer := data.get_attribute_id('system_person_notification_count');

  v_notifications_id integer := data.get_object_id('notifications');
  v_notification_count integer :=
    json.get_integer(data.get_attribute_value_for_update(in_actor_id, v_system_person_notification_count_attribute_id)) + 1;
begin
  if in_redirect_object is not null then
    v_object_code := data.get_object_code(in_redirect_object);
    v_notification_title := in_text || E'\n\n' || pp_utils.link(v_object_code);
  else
    v_notification_title := in_text;
  end if;

  -- создаём новый объект для нотификации
  insert into data.objects(class_id) values(data.get_class_id('notification')) returning id, code into v_notification_id, v_notification_code;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_notification_id, v_title_attribute_id, to_jsonb(v_notification_title), null),
  (v_notification_id, v_is_visible_attribute_id, jsonb 'true', in_actor_id);
  if in_redirect_object is not null then
    insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
    (v_notification_id, v_redirect_attribute_id, to_jsonb(in_redirect_object), null);
  end if;

  -- Вставляем в начало списка и рассылаем уведомления
  perform pp_utils.list_prepend_and_notify(v_notifications_id, v_notification_code, in_actor_id);
  perform data.change_object_and_notify(in_actor_id, jsonb '[]' || data.attribute_change2jsonb(v_system_person_notification_count_attribute_id, to_jsonb(v_notification_count)));

  if in_is_important then
    perform pallas_project.send_to_important_notifications(in_actor_id, in_text, v_object_code);
  end if;
end;
$$
language plpgsql;

-- drop function pp_utils.add_notification_if_not_subscribed(integer, text, integer, boolean);

create or replace function pp_utils.add_notification_if_not_subscribed(in_actor_id integer, in_text text, in_redirect_object integer, in_is_important boolean default false)
returns void
volatile
as
$$
declare
  v_exists integer;
begin
  -- Ищем подписку на этот объект у этого актора
  select count(s.object_id) into v_exists
  from data.clients c
  inner join data.client_subscriptions s on s.client_id = c.id and s.object_id = in_redirect_object
  where c.actor_id = in_actor_id;

  if v_exists = 0 then
    perform pp_utils.add_notification(in_actor_id, in_text, in_redirect_object, in_is_important);
  end if;

end;
$$
language plpgsql;

-- drop function pp_utils.add_word_ending(text, bigint);

create or replace function pp_utils.add_word_ending(in_word text, in_count bigint)
returns text
immutable
as
$$
begin
  if in_count % 10 = 0 or in_count % 10 >= 5 or in_count > 10 and in_count < 20 then
    return in_word || 'ов';
  elsif in_count % 10 = 1 then
    return in_word;
  end if;

  return in_word || 'а';
end;
$$
language plpgsql;

-- drop function pp_utils.format_date(timestamp with time zone);

create or replace function pp_utils.format_date(in_time timestamp with time zone)
returns text
stable
as
$$
begin
  return format(to_char(in_time, 'DD.MM.%s HH24:MI:SS'), data.get_integer_param('year'));
end;
$$
language plpgsql;

-- drop function pp_utils.format_money(bigint);

create or replace function pp_utils.format_money(in_value bigint)
returns text
immutable
as
$$
begin
  if in_value < 0 then
    return '−UN$' || abs(in_value);
  end if;

  return 'UN$' || in_value;
end;
$$
language plpgsql;

-- drop function pp_utils.is_actor_subscribed(integer, integer);

create or replace function pp_utils.is_actor_subscribed(in_actor_id integer, in_object integer)
returns boolean
stable
as
$$
declare
  v_exists integer;
begin
  -- Ищем подписку на этот объект у этого актора
  select count(s.object_id) into v_exists
  from data.clients c
  inner join data.client_subscriptions s on s.client_id = c.id and s.object_id = in_object
  where c.actor_id = in_actor_id;

  if v_exists > 0 then
    return true;
  else 
    return false;
  end if;
end;
$$
language plpgsql;

-- drop function pp_utils.is_in_group(integer, text);

create or replace function pp_utils.is_in_group(in_object_id integer, in_group_code text)
returns boolean
stable
as
$$
declare
  v_group_id integer := data.get_object_id(in_group_code);
  v_count integer; 
begin
  select count(1) into v_count from data.object_objects oo
  where oo.object_id = in_object_id
    and oo.parent_object_id = v_group_id;

  if v_count > 0 then
    return true;
  else 
    return false;
  end if;
end;
$$
language plpgsql;

-- drop function pp_utils.link(integer);

create or replace function pp_utils.link(in_object_id integer)
returns text
stable
as
$$
declare
  v_title text := json.get_string_opt(data.get_attribute_value(in_object_id, 'title'), '???');
begin
  return format('[%s](babcom:%s)', v_title, data.get_object_code(in_object_id));
end;
$$
language plpgsql;

-- drop function pp_utils.link(text);

create or replace function pp_utils.link(in_code text)
returns text
stable
as
$$
declare
  v_title text := json.get_string_opt(data.get_attribute_value(data.get_object_id(in_code), 'title'), '???');
begin
  return format('[%s](babcom:%s)', v_title, in_code);
end;
$$
language plpgsql;

-- drop function pp_utils.list_prepend_and_notify(integer, text, integer, integer);

create or replace function pp_utils.list_prepend_and_notify(in_list_id integer, in_new_object_code text, in_value_object_id integer, in_actor_id integer default null::integer)
returns void
volatile
as
$$
declare
  v_content_attribute_id integer := data.get_attribute_id('content');

  v_content jsonb;
  v_actor_id integer := coalesce(in_actor_id, in_value_object_id);
begin
  assert in_new_object_code is not null;

  -- Достаём, меняем, кладём назад
  v_content := coalesce(data.get_raw_attribute_value_for_update(in_list_id, 'content', in_value_object_id), jsonb '[]');
  v_content := to_jsonb(in_new_object_code) || v_content;
  perform data.change_object_and_notify(
    in_list_id, 
    jsonb '[]' || data.attribute_change2jsonb(v_content_attribute_id, v_content, in_value_object_id),
    v_actor_id);
end;
$$
language plpgsql;

-- drop function pp_utils.list_remove_and_notify(integer, text, integer);

create or replace function pp_utils.list_remove_and_notify(in_list_id integer, in_object_code text, in_actor_id integer)
returns void
volatile
as
$$
-- Функция перемещает элемент в начало массива
declare
  v_content_attribute_id integer := data.get_attribute_id('content');

  v_content text[];
  v_new_content text[];

begin
  -- Достаём, меняем, кладём назад
  v_content := json.get_string_array_opt(data.get_raw_attribute_value_for_update(in_list_id, 'content', in_actor_id), array[]::text[]);
  v_new_content := array_remove(v_content, in_object_code);
  if v_new_content <> v_content then
    perform data.change_object_and_notify(in_list_id, 
                                          jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, to_jsonb(v_new_content), in_actor_id)),
                                          in_actor_id);
  end if;
end;
$$
language plpgsql;

-- drop function pp_utils.list_replace_to_head_and_notify(integer, text, integer);

create or replace function pp_utils.list_replace_to_head_and_notify(in_list_id integer, in_object_code text, in_actor_id integer)
returns void
volatile
as
$$
-- Функция перемещает элемент в начало массива
declare
  v_content_attribute_id integer := data.get_attribute_id('content');

  v_content text[];
  v_new_content text[];

begin
  -- Достаём, меняем, кладём назад
  v_content := json.get_string_array_opt(data.get_raw_attribute_value_for_update(in_list_id, 'content', in_actor_id), array[]::text[]);
  v_new_content := array_remove(v_content, in_object_code);
  v_new_content := array_prepend(in_object_code, v_new_content);
  if v_new_content <> v_content then
    perform data.change_object_and_notify(in_list_id,
                                          jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, to_jsonb(v_new_content), in_actor_id)),
                                          in_actor_id);
  end if;
end;
$$
language plpgsql;

-- drop function pp_utils.trim(text);

create or replace function pp_utils.trim(in_text text)
returns text
immutable
as
$$
begin
  return trim(in_text, E' \t\n');
end;
$$
language plpgsql;

-- drop function random.random_bigint(bigint, bigint);

create or replace function random.random_bigint(in_min_value bigint, in_max_value bigint)
returns bigint
volatile
as
$$
-- Возвращает случайное число от in_min_value до in_max_value включительно
declare
  v_random_double double precision := random();
begin
  assert in_min_value is not null;
  assert in_max_value is not null;
  assert in_min_value <= in_max_value is not null;

  if in_min_value = in_max_value then
    return in_min_value;
  end if;

  return floor(in_min_value + v_random_double * (in_max_value - in_min_value + 1));
end;
$$
language plpgsql;

-- drop function random.random_integer(integer, integer);

create or replace function random.random_integer(in_min_value integer, in_max_value integer)
returns integer
volatile
as
$$
-- Возвращает случайное число от in_min_value до in_max_value включительно
declare
  v_random_double double precision := random();
begin
  assert in_min_value is not null;
  assert in_max_value is not null;
  assert in_min_value <= in_max_value is not null;

  if in_min_value = in_max_value then
    return in_min_value;
  end if;

  return floor(in_min_value + v_random_double * (in_max_value - in_min_value + 1));
end;
$$
language plpgsql;

-- drop function random_test.random_x_should_return_exact_value();

create or replace function random_test.random_x_should_return_exact_value()
returns void
immutable
as
$$
declare
  v_type text;
  v_value text := '5';
begin
  foreach v_type in array array ['bigint', 'integer'] loop
    execute 'select test.assert_eq(5, random.random_' || v_type || '(' || v_value || ', ' || v_value || '))';
  end loop;
end;
$$
language plpgsql;

-- drop function random_test.random_x_should_return_ge_than_min_value();

create or replace function random_test.random_x_should_return_ge_than_min_value()
returns void
immutable
as
$$
declare
  v_type text;
  v_min_value text := '-5';
  v_max_value text := '-2';
begin
  foreach v_type in array array ['bigint', 'integer'] loop
    execute 'select test.assert_le(' || v_min_value || ', random.random_' || v_type || '(' || v_min_value || ', ' || v_max_value || '))';
  end loop;
end;
$$
language plpgsql;

-- drop function random_test.random_x_should_return_le_than_max_value();

create or replace function random_test.random_x_should_return_le_than_max_value()
returns void
immutable
as
$$
declare
  v_type text;
  v_min_value text := '2';
  v_max_value text := '5';
begin
  foreach v_type in array array ['bigint', 'integer'] loop
    execute 'select test.assert_ge(' || v_max_value || ', random.random_' || v_type || '(' || v_min_value || ', ' || v_max_value || '))';
  end loop;
end;
$$
language plpgsql;

-- drop function test.assert_caseeq(text, text);

create or replace function test.assert_caseeq(in_expected text, in_actual text)
returns void
immutable
as
$$
-- Проверяет, что реальное значение равно ожидаемому без учёта регистра
-- Если оба значения null, то это считается равенством
-- Если ожидаемое значение null, то и реальное должно быть null
begin
  if
    (
      in_expected is null and
      in_actual is not null
    ) or
    (
      in_expected is not null and
      (
        in_actual is null or
        lower(in_expected) != lower(in_actual)
      )
    )
  then
    raise exception 'Assert_caseeq failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_casene(text, text);

create or replace function test.assert_casene(in_expected text, in_actual text)
returns void
immutable
as
$$
-- Проверяет, что реальное значение не равно ожидаемому без учёта регистра
-- Если оба значения null, то это считается равенством
-- Если ожидаемое значение null, то реальное не должно быть null
begin
  if
    (
      in_expected is null and
      in_actual is null
    ) or
    (
      in_expected is not null and
      in_actual is not null and
      lower(in_expected) = lower(in_actual)
    )
  then
    raise exception 'Assert_casene failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_eq(bigint, bigint);

create or replace function test.assert_eq(in_expected bigint, in_actual bigint)
returns void
immutable
as
$$
-- Проверяет, что реальное значение равно ожидаемому
-- Если оба значения null, то это считается равенством
-- Если ожидаемое значение null, то и реальное должно быть null
begin
  if
    (
      in_expected is null and
      in_actual is not null
    ) or
    (
      in_expected is not null and
      (
        in_actual is null or
        in_expected != in_actual
      )
    )
  then
    raise exception 'Assert_eq failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_eq(bigint[], bigint[]);

create or replace function test.assert_eq(in_expected bigint[], in_actual bigint[])
returns void
immutable
as
$$
-- Проверяет, что реальное содержимое массива равно ожидаемому
-- Если оба значения null, то это считается равенством
-- Если ожидаемое значение null, то и реальное должно быть null
begin
  if
    (
      in_expected is null and
      in_actual is not null
    ) or
    (
      in_expected is not null and
      (
        in_actual is null or
        in_expected != in_actual
      )
    )
  then
    raise exception 'Assert_eq failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_eq(json, json);

create or replace function test.assert_eq(in_expected json, in_actual json)
returns void
immutable
as
$$
-- Проверяет, что реальное значение равно ожидаемому
-- Если оба значения null, то это считается равенством
-- Если ожидаемое значение null, то и реальное должно быть null
begin
  if
    (
      in_expected is null and
      in_actual is not null
    ) or
    (
      in_expected is not null and
      (
        in_actual is null or
        in_expected::jsonb != in_actual::jsonb
      )
    )
  then
    raise exception 'Assert_eq failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_eq(jsonb, jsonb);

create or replace function test.assert_eq(in_expected jsonb, in_actual jsonb)
returns void
immutable
as
$$
-- Проверяет, что реальное значение равно ожидаемому
-- Если оба значения null, то это считается равенством
-- Если ожидаемое значение null, то и реальное должно быть null
begin
  if
    (
      in_expected is null and
      in_actual is not null
    ) or
    (
      in_expected is not null and
      (
        in_actual is null or
        in_expected != in_actual
      )
    )
  then
    raise exception 'Assert_eq failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_eq(text, text);

create or replace function test.assert_eq(in_expected text, in_actual text)
returns void
immutable
as
$$
-- Проверяет, что реальное значение равно ожидаемому
-- Если оба значения null, то это считается равенством
-- Если ожидаемое значение null, то и реальное должно быть null
begin
  if
    (
      in_expected is null and
      in_actual is not null
    ) or
    (
      in_expected is not null and
      (
        in_actual is null or
        in_expected != in_actual
      )
    )
  then
    raise exception 'Assert_eq failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_eq(text[], text[]);

create or replace function test.assert_eq(in_expected text[], in_actual text[])
returns void
immutable
as
$$
-- Проверяет, что реальное содержимое массива равно ожидаемому
-- Если оба значения null, то это считается равенством
-- Если ожидаемое значение null, то и реальное должно быть null
begin
  if
    (
      in_expected is null and
      in_actual is not null
    ) or
    (
      in_expected is not null and
      (
        in_actual is null or
        in_expected != in_actual
      )
    )
  then
    raise exception 'Assert_eq failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_false(boolean);

create or replace function test.assert_false(in_expression boolean)
returns void
immutable
as
$$
-- Проверяет, что выражение ложно
begin
  if in_expression is null or in_expression = true then
    raise exception 'Assert_false failed.';
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_ge(bigint, bigint);

create or replace function test.assert_ge(in_expected bigint, in_actual bigint)
returns void
immutable
as
$$
-- Проверяет, что ожидаемое значение больше или равно реальному
begin
  if in_expected is null or in_actual is null or in_expected < in_actual then
    raise exception 'Assert_ge failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_gt(bigint, bigint);

create or replace function test.assert_gt(in_expected bigint, in_actual bigint)
returns void
immutable
as
$$
-- Проверяет, что ожидаемое значение больше реального
begin
  if in_expected is null or in_actual is null or in_expected <= in_actual then
    raise exception 'Assert_gt failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_le(bigint, bigint);

create or replace function test.assert_le(in_expected bigint, in_actual bigint)
returns void
immutable
as
$$
-- Проверяет, что ожидаемое значение меньше или равно реальному
begin
  if in_expected is null or in_actual is null or in_expected > in_actual then
    raise exception 'Assert_le failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_lt(bigint, bigint);

create or replace function test.assert_lt(in_expected bigint, in_actual bigint)
returns void
immutable
as
$$
-- Проверяет, что ожидаемое значение меньше реального
begin
  if in_expected is null or in_actual is null or in_expected >= in_actual then
    raise exception 'Assert_lt failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_ne(bigint, bigint);

create or replace function test.assert_ne(in_expected bigint, in_actual bigint)
returns void
immutable
as
$$
-- Проверяет, что реальное значение не равно ожидаемому
-- Если оба значения null, то это считается равенством
-- Если ожидаемое значение null, то реальное не должно быть null
begin
  if
    (
      in_expected is null and
      in_actual is null
    ) or
    (
      in_expected is not null and
      in_actual is not null and
      in_expected = in_actual
    )
  then
    raise exception 'Assert_ne failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_ne(bigint[], bigint[]);

create or replace function test.assert_ne(in_expected bigint[], in_actual bigint[])
returns void
immutable
as
$$
-- Проверяет, что реальное значение массива не равно ожидаемому
-- Если оба значения null, то это считается равенством
-- Если ожидаемое значение null, то реальное не должно быть null
begin
  if
    (
      in_expected is null and
      in_actual is null
    ) or
    (
      in_expected is not null and
      in_actual is not null and
      in_expected = in_actual
    )
  then
    raise exception 'Assert_ne failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_ne(json, json);

create or replace function test.assert_ne(in_expected json, in_actual json)
returns void
immutable
as
$$
-- Проверяет, что реальное значение не равно ожидаемому
-- Если оба значения null, то это считается равенством
-- Если ожидаемое значение null, то реальное не должно быть null
begin
  if
    (
      in_expected is null and
      in_actual is null
    ) or
    (
      in_expected is not null and
      in_actual is not null and
      in_expected::jsonb = in_actual::jsonb
    )
  then
    raise exception 'Assert_ne failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_ne(jsonb, jsonb);

create or replace function test.assert_ne(in_expected jsonb, in_actual jsonb)
returns void
immutable
as
$$
-- Проверяет, что реальное значение не равно ожидаемому
-- Если оба значения null, то это считается равенством
-- Если ожидаемое значение null, то реальное не должно быть null
begin
  if
    (
      in_expected is null and
      in_actual is null
    ) or
    (
      in_expected is not null and
      in_actual is not null and
      in_expected = in_actual
    )
  then
    raise exception 'Assert_ne failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_ne(text, text);

create or replace function test.assert_ne(in_expected text, in_actual text)
returns void
immutable
as
$$
-- Проверяет, что реальное значение не равно ожидаемому
-- Если оба значения null, то это считается равенством
-- Если ожидаемое значение null, то реальное не должно быть null
begin
  if
    (
      in_expected is null and
      in_actual is null
    ) or
    (
      in_expected is not null and
      in_actual is not null and
      in_expected = in_actual
    )
  then
    raise exception 'Assert_ne failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_ne(text[], text[]);

create or replace function test.assert_ne(in_expected text[], in_actual text[])
returns void
immutable
as
$$
-- Проверяет, что реальное значение массива не равно ожидаемому
-- Если оба значения null, то это считается равенством
-- Если ожидаемое значение null, то реальное не должно быть null
begin
  if
    (
      in_expected is null and
      in_actual is null
    ) or
    (
      in_expected is not null and
      in_actual is not null and
      in_expected = in_actual
    )
  then
    raise exception 'Assert_ne failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_no_throw(text);

create or replace function test.assert_no_throw(in_expression text)
returns void
volatile
as
$$
-- Проверяет, что выражение не генерирует исключения
declare
  v_exception boolean := false;
  v_exception_message text;
  v_exception_call_stack text;
begin
  assert in_expression is not null;

  begin
    execute in_expression;
  exception when others then
    get stacked diagnostics
      v_exception_message = message_text,
      v_exception_call_stack = pg_exception_context;

    v_exception := true;
  end;

  if v_exception then
    raise exception E'Assert_no_throw failed.\nMessage: %.\nCall stack:\n%', v_exception_message, v_exception_call_stack;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_not_null(bigint);

create or replace function test.assert_not_null(in_expression bigint)
returns void
immutable
as
$$
-- Проверяет, что выражение не является null
begin
  if in_expression is null then
    raise exception 'Assert_not_null failed.';
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_not_null(boolean);

create or replace function test.assert_not_null(in_expression boolean)
returns void
immutable
as
$$
-- Проверяет, что выражение не является null
begin
  if in_expression is null then
    raise exception 'Assert_not_null failed.';
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_not_null(text);

create or replace function test.assert_not_null(in_expression text)
returns void
immutable
as
$$
-- Проверяет, что выражение не является null
begin
  if in_expression is null then
    raise exception 'Assert_not_null failed.';
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_null(bigint);

create or replace function test.assert_null(in_expression bigint)
returns void
immutable
as
$$
-- Проверяет, что выражение является null
begin
  if in_expression is not null then
    raise exception 'Assert_null failed.';
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_null(boolean);

create or replace function test.assert_null(in_expression boolean)
returns void
immutable
as
$$
-- Проверяет, что выражение является null
begin
  if in_expression is not null then
    raise exception 'Assert_null failed.';
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_null(text);

create or replace function test.assert_null(in_expression text)
returns void
immutable
as
$$
-- Проверяет, что выражение является null
begin
  if in_expression is not null then
    raise exception 'Assert_null failed.';
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_throw(text, text);

create or replace function test.assert_throw(in_expression text, in_exception_pattern text default null::text)
returns void
volatile
as
$$
-- Проверяет, что выражение генерирует исключение
declare
  v_exception boolean := false;
  v_exception_message text;
  v_exception_call_stack text;
begin
  assert in_expression is not null;

  begin
    execute in_expression;
  exception when others then
    get stacked diagnostics
      v_exception_message = message_text,
      v_exception_call_stack = pg_exception_context;

    v_exception := true;
  end;

  if not v_exception then
    raise exception 'Assert_throw failed.';
  end if;

  if in_exception_pattern is not null and v_exception_message not like in_exception_pattern then
    raise exception E'Assert_throw failed.\nExpected exception with pattern: %\nGot: %\nCall stack:\n%', in_exception_pattern, v_exception_message, v_exception_call_stack;
  end if;
end;
$$
language plpgsql;

-- drop function test.assert_true(boolean);

create or replace function test.assert_true(in_expression boolean)
returns void
immutable
as
$$
-- Проверяет, что выражение истинно
begin
  if in_expression is null or in_expression = false then
    raise exception 'Assert_true failed.';
  end if;
end;
$$
language plpgsql;

-- drop function test.fail(text);

create or replace function test.fail(in_description text default null::text)
returns void
immutable
as
$$
-- Всегда генерирует исключение
begin
  if in_description is not null then
    raise exception 'Fail. Description: %', in_description;
  else
    raise exception 'Fail.';
  end if;
end;
$$
language plpgsql;

-- drop function test.run_all_tests();

create or replace function test.run_all_tests()
returns boolean
volatile
as
$$
-- Тесты запускаются в пустой базе
-- Ищутся и запускаются функции *_test.*, возвращающие void и не имеющие входных параметров
-- Тест считается успешно выполненным, если он не выбросил исключения
declare
  v_total_test_cases_count integer;
  v_total_tests_count integer;

  v_total_tests_text text;
  v_total_test_cases_text text;

  v_failed_tests text[];

  v_start timestamp with time zone := clock_timestamp();
begin
  -- Определяем количество тест-кейсов
  select count(1)
  into v_total_test_cases_count
  from pg_namespace
  where nspname like '%_test';

  -- Определяем количество тестов
  select count(1)
  into v_total_tests_count
  from pg_proc
  where
    pronamespace in
      (
        select oid
        from pg_namespace
        where nspname like '%_test'
      ) and
    prorettype =
      (
        select oid
        from pg_type
        where typname = 'void'
      ) and
    pronargs = 0 and
    proname not like 'disabled_%' and
    proname != 'set_up_test_case';

  if v_total_tests_count = 1 then
    v_total_tests_text := '1 test';
  else
    v_total_tests_text := v_total_tests_count || ' tests';
  end if;

  if v_total_test_cases_count = 1 then
    v_total_test_cases_text := '1 test case';
  else
    v_total_test_cases_text := v_total_test_cases_count || ' test cases';
  end if;

  raise notice '[==========] Running % from %.', v_total_tests_text, v_total_test_cases_text;

  declare
    v_void_type_id integer;

    v_test_case record;

    v_tests_count integer;
    v_tests_text text;

    v_test_case_start timestamp with time zone;
  begin
    -- Определяем id типа void для пропуска функций, возвращающих какое-то значение
    select oid
    into v_void_type_id
    from pg_type
    where typname = 'void';

    for v_test_case in
    (
      select oid as id, nspname as name
      from pg_namespace
      where nspname like '%_test'
      order by name
    )
    loop
      -- Считаем количество тестов в тест-кейсе
      select count(1)
      into v_tests_count
      from pg_proc
      where
        pronamespace = v_test_case.id and
        prorettype = v_void_type_id and
        pronargs = 0 and
        proname not like 'disabled_%' and
        proname != 'set_up_test_case';

      if v_tests_count = 1 then
        v_tests_text := '1 test';
      else
        v_tests_text := v_tests_count || ' tests';
      end if;

      v_test_case_start := clock_timestamp();

      raise notice '[----------] % from %', v_tests_text, v_test_case.name;

      declare
        v_test record;
        v_set_up record;
        v_need_tear_down boolean := false;

        v_test_name text;
        v_test_start timestamp with time zone;
        v_test_time integer;

        v_failed boolean;
      begin
        for v_set_up in
        (
          select
            proname as name,
            prorettype as type,
            pronargs as arg_count,
            provolatile as volative
          from pg_proc
          where
            pronamespace = v_test_case.id and
            proname = 'set_up_test_case'
        )
        loop
          if v_set_up.type != v_void_type_id then
            raise notice ' SKIPPING SET UP FUNCTION FOR TEST CASE % DUE TO NON-VOID RETURN VALUE', v_test_case.name;
            continue;
          end if;

          if v_set_up.arg_count != 0 then
            raise notice ' SKIPPING SET UP FUNCTION FOR TEST CASE % DUE TO MORE THAN ZERO ARGUMENTS', v_test_case.name;
            continue;
          end if;

          if v_set_up.volative != 'v' then
            raise notice ' SKIPPING NON-VOLATILE SET UP FUNCTION FOR TEST CASE %', v_test_case.name;
            continue;
          end if;

          v_need_tear_down := true;
        end loop;

        if v_need_tear_down then
          declare
            v_exception_call_stack text;
            v_exception_message text;
          begin
            execute 'select ' || v_test_case.name || '.set_up_test_case()';

          exception when others then
            -- Выводим сообщение об ошибке
            get stacked diagnostics
              v_exception_message = message_text,
              v_exception_call_stack = pg_exception_context;

            raise notice E' TEST CASE SET UP FAILED FOR %\n%\n%', v_test_case.name, v_exception_call_stack, v_exception_message;

            for v_test in
            (
              select proname as name
              from pg_proc
              where
                pronamespace = v_test_case.id and
                prorettype = v_void_type_id and
                pronargs = 0 and
                proname not like 'disabled_%' and
                proname != 'set_up_test_case'
              order by name
            )
            loop
              v_test_name := v_test_case.name || '.' || v_test.name;

              v_failed_tests := array_append(v_failed_tests, v_test_name);
            end loop;

            continue;
          end;
        end if;

        for v_test in
        (
          select
            proname as name,
            prorettype as type,
            pronargs as arg_count,
            provolatile as volative
          from pg_proc
          where
            pronamespace = v_test_case.id and
            proname not like 'disabled_%' and
            proname != 'set_up_test_case'
          order by name
        )
        loop
          v_test_name := v_test_case.name || '.' || v_test.name;

          if v_test.type != v_void_type_id then
            raise notice ' SKIPPING FUNCTION % DUE TO NON-VOID RETURN VALUE', v_test_name;
            continue;
          end if;

          if v_test.arg_count != 0 then
            raise notice ' SKIPPING FUNCTION % DUE TO MORE THAN ZERO ARGUMENTS', v_test_name;
            continue;
          end if;

          v_test_start := clock_timestamp();

          raise notice '[ RUN      ] %', v_test_name;

          begin
            declare
              v_exception_call_stack text;
              v_exception_message text;
            begin
              -- Выполняем процедуру
              execute 'select ' || v_test_name || '()';

              v_failed := false;
            exception when others then
              -- Выводим сообщение об ошибке
              get stacked diagnostics
                v_exception_message = message_text,
                v_exception_call_stack = pg_exception_context;

              raise notice E'%\n%', v_exception_call_stack, v_exception_message;
              v_failed := true;

              v_failed_tests := array_append(v_failed_tests, v_test_name);
            end;

            -- Изменения тестов, которые могли менять содержимое БД, нужно откатить
            if !v_failed and v_test.volative = 'v' then
              raise exception 'Rollback';
            end if;
          exception when others then
          end;

          v_test_time := round(extract(milliseconds from clock_timestamp() - v_test_start));

          if v_failed then
            raise notice '[  FAILED  ] % (% ms total)', v_test_name, v_test_time;
          else
            raise notice '[       OK ] % (% ms total)', v_test_name, v_test_time;
          end if;
        end loop;

        -- Откатываем изменения тест кейса, если была его инициализация
        if v_need_tear_down then
          raise exception 'Rollback';
        end if;
      exception when others then
      end;

      raise notice '[----------] % from % (% ms total)', v_tests_text, v_test_case.name, round(extract(milliseconds from clock_timestamp() - v_test_case_start));
      raise notice '';
    end loop;
  end;

  raise notice '[==========] % from % ran. (% ms total)', v_total_tests_text, v_total_test_cases_text, round(extract(milliseconds from clock_timestamp() - v_start));

  declare
    v_disabled_tests_count integer;
    v_failed_tests_count integer := coalesce(array_length(v_failed_tests, 1), 0);
    v_passed_tests_count integer := v_total_tests_count - v_failed_tests_count;
    v_passed_tests_text text;
  begin
    if v_passed_tests_count = 1 then
      v_passed_tests_text := '1 test';
    else
      v_passed_tests_text := v_passed_tests_count || ' tests';
    end if;

    raise notice '[  PASSED  ] %.', v_passed_tests_text;

    if v_failed_tests_count != 0 then
      declare
        v_failed_tests_text text;
        v_failed_test text;
      begin
        if v_failed_tests_count = 1 then
          v_failed_tests_text := 'test';
        else
          v_failed_tests_text := 'tests';
        end if;

        raise notice '[  FAILED  ] % %, listed below:', v_failed_tests_count, v_failed_tests_text;

        foreach v_failed_test in array v_failed_tests loop
          raise notice '[  FAILED  ] %', v_failed_test;
        end loop;

        raise notice '';
        raise notice ' % FAILED %', v_failed_tests_count, upper(v_failed_tests_text);
      end;
    end if;

    select count(1)
    into v_disabled_tests_count
    from pg_proc
    where
      pronamespace in
        (
          select oid
          from pg_namespace
          where nspname like '%_test'
        ) and
      prorettype =
        (
          select oid
          from pg_type
          where typname = 'void'
        ) and
      pronargs = 0 and
      proname like 'disabled_%';

    if v_disabled_tests_count != 0 then
      declare
        v_disabled_tests_text text;
      begin
        if v_failed_tests_count = 0 then
          raise notice '';
        end if;

        if v_disabled_tests_count = 1 then
          v_disabled_tests_text := 'DISABLED TEST';
        else
          v_disabled_tests_text := 'DISABLED TESTS';
        end if;

        raise notice '  YOU HAVE % %', v_disabled_tests_count, v_disabled_tests_text;
      end;
    end if;

    if v_failed_tests_count != 0 then
      return false;
    end if;
  end;

  return true;
end;
$$
language plpgsql;

-- drop function test_project.diff_action(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.diff_action(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_title text := test_project.next_code(json.get_string(in_params, 'title'));
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_object_code text := data.get_object_code(v_object_id);
  v_state text := json.get_string(data.get_attribute_value(v_object_id, 'test_state'));
  v_changes jsonb := jsonb '[]';
begin
  assert in_request_id is not null;
  assert test_project.is_user_params_empty(in_user_params);
  assert in_default_params is null;

  if v_state = 'state1' then
    v_changes := v_changes || data.attribute_change2jsonb('test_state', jsonb '"state2"');
    v_changes := v_changes || data.attribute_change2jsonb('title', to_jsonb(v_title));
    v_changes := v_changes || data.attribute_change2jsonb('description', to_jsonb(
'**Проверка 1:** Заголовок изменился на "' || v_title || '".
**Проверка 2:** Название кнопки поменялось на "Вперёд!".
**Проверка 3:** Действие в очередной раз полностью меняет отображаемые данные.'));
  elsif v_state = 'state2' then
    v_changes := v_changes || data.attribute_change2jsonb('test_state', jsonb '"state3"');
    v_changes := v_changes || data.attribute_change2jsonb('title', to_jsonb(v_title));
    v_changes := v_changes || data.attribute_change2jsonb('subtitle', jsonb '"Тест на удаление и добавление атрибутов"');
    v_changes := v_changes || data.attribute_change2jsonb('description', null);
    v_changes := v_changes || data.attribute_change2jsonb('template', jsonb '{"title": "title", "subtitle": "subtitle", "groups": [{"code": "not_so_common", "attributes": ["description2"]}]}');
    v_changes := v_changes || data.attribute_change2jsonb('description2', to_jsonb(text
'В этот раз мы не изменяли значение атрибута, а удалили старый и добавили новый. Также какое-то действие возвращается, но оно отсутствует в шаблоне.

**Проверка 1:** Под заголовком гордо красуется подзаголовок.
**Проверка 2:** Старого текста нигде нет.
**Проверка 3:** Действий тоже нет.

[Продолжить](babcom:test' || (test_project.get_suffix(v_title) + 1) || ')'));
  end if;

  assert v_changes != jsonb '[]';

  if not data.change_current_object(in_client_id, in_request_id, v_object_id, v_changes) then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function test_project.diff_action_generator(integer, integer);

create or replace function test_project.diff_action_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_state text := json.get_string(data.get_attribute_value(in_object_id, 'test_state'));
  v_name text := case when v_state = 'state2' then 'Вперёд!' else 'Далее' end;
  v_title text := json.get_string(data.get_attribute_value(in_object_id, 'title', in_actor_id));
begin
  return format('{"action": {"code": "diff", "name": "%s", "disabled": false, "params": {"title": "%s", "object_id": %s}}}', v_name, v_title, in_object_id)::jsonb;
end;
$$
language plpgsql;

-- drop function test_project.do_nothing_action(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.do_nothing_action(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
begin
  perform data.get_active_actor_id(in_client_id);

  assert in_request_id is not null;
  assert in_params = jsonb 'null';
  assert test_project.is_user_params_empty(in_user_params);
  assert in_default_params is null;

  perform api_utils.create_ok_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;

-- drop function test_project.do_nothing_list_action_generator(integer, integer, integer);

create or replace function test_project.do_nothing_list_action_generator(in_object_id integer, in_list_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_title_attribute jsonb := data.get_attribute_value(in_list_object_id, 'title', in_actor_id);
begin
  assert data.is_instance(in_object_id);

  if v_title_attribute = jsonb '"Duo"' then
    return jsonb '{"action": {"code": "do_nothing", "name": "Я кнопка", "disabled": false, "params": null}}';
  end if;

  return jsonb '{}';
end;
$$
language plpgsql;

-- drop function test_project.get_suffix(text);

create or replace function test_project.get_suffix(in_code text)
returns integer
immutable
as
$$
declare
  v_prefix text := trim(trailing '0123456789' from in_code);
begin
  return substring(in_code from char_length(v_prefix) + 1)::integer;
end;
$$
language plpgsql;

-- drop function test_project.init();

create or replace function test_project.init()
returns void
volatile
as
$$
declare
  v_type_attribute_id integer := data.get_attribute_id('type');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_subtitle_attribute_id integer := data.get_attribute_id('subtitle');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_actions_function_attribute_id integer := data.get_attribute_id('actions_function');
  v_full_card_function_attribute_id integer := data.get_attribute_id('full_card_function');
  v_list_actions_function_attribute_id integer := data.get_attribute_id('list_actions_function');
  v_description_attribute_id integer;

  v_menu_id integer;
  v_notifications_id integer;

  v_test_id integer;
  v_test_num integer := 2;

  v_template_groups jsonb[];
begin
  -- Базовые настройки
  update data.params
  set value = jsonb '5'
  where code = 'page_size';

  -- Атрибут для какого-то текста
  insert into data.attributes(code, type, card_type, can_be_overridden)
  values('description', 'normal', 'full', true)
  returning id into v_description_attribute_id;

  -- Накидаем атрибутов для различного использования
  insert into data.attributes(code, type, name, card_type, can_be_overridden, value_description_function) values
  ('description2', 'normal', null, null, true, null),
  ('test_state', 'system', null, null, false, null),
  ('short_card_attribute', 'normal', 'Атрибут миникарточки', 'mini', true, null),
  ('attribute', 'normal', 'Обычный атрибут', null, true, null),
  ('attribute_with_description', 'normal', null, null, true, 'test_project.test_value_description_function');

  -- И первая группа в шаблоне
  v_template_groups := array_append(v_template_groups, jsonb '{"code": "common", "attributes": ["description"], "actions": ["action"]}');

  -- Создадим актора по умолчанию, который является первым тестом
  insert into data.objects(code) values('test1') returning id into v_test_id;

  -- Создадим объект для страницы 404
  declare
    v_not_found_object_id integer;
  begin
    insert into data.objects(code) values('not_found') returning id into v_not_found_object_id;
    insert into data.params(code, value, description)
    values('not_found_object_id', to_jsonb(v_not_found_object_id), 'Идентификатор объекта, отображаемого в случае, если актору недоступен какой-то объект (ну или он реально не существует)');

    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_not_found_object_id, v_type_attribute_id, jsonb '"not_found"'),
    (v_not_found_object_id, v_is_visible_attribute_id, jsonb 'true'),
    (v_not_found_object_id, v_title_attribute_id, jsonb '"404"'),
    (v_not_found_object_id, v_subtitle_attribute_id, jsonb '"Not found"'),
    (v_not_found_object_id, v_description_attribute_id, jsonb '"Это не те дроиды, которых вы ищете."');
  end;

  -- Логин по умолчанию
  declare
    v_default_login_id integer;
  begin
    insert into data.logins(code) values('default_login') returning id into v_default_login_id;
    insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_test_id);

    insert into data.params(code, value, description)
    values('default_login_id', to_jsonb(v_default_login_id), 'Идентификатор логина по умолчанию');
  end;

  -- Также для работы нам понадобится пустой объект меню
  insert into data.objects(code) values('menu') returning id into v_menu_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_menu_id, v_type_attribute_id, jsonb '"menu"'),
  (v_menu_id, v_is_visible_attribute_id, jsonb 'true');

  -- И пустой список уведомлений
  insert into data.objects(code) values('notifications') returning id into v_notifications_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_notifications_id, v_type_attribute_id, jsonb '"notifications"'),
  (v_notifications_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_notifications_id, v_content_attribute_id, jsonb '[]');

  -- Базовый тест:
  -- - пустые заголовки, подзаголовки, меню, список уведомлений
  -- - переводы строк
  -- - экранирование
  -- - автовыбор актора при старте приложения
  -- - только атрибуты из шаблона
  -- - ссылка

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Добрый день!
Если приложение было запущено первый раз, то первое, что вы должны были увидеть (не считая возможных лоадеров) — это этот текст.
У нас сейчас пустое меню, пустой список непрочитанных уведомлений, а список акторов состоит из одного объекта — того, который открыт прямо сейчас.
Единственный актор в списке не имеет ни заголовка, ни подзаголовка.

Проверка 1: Этот текст разбит на строки. В частности, новая строка начинается сразу после текста "Добрый день!".
Так, если клиент выводит текст в разметке HTML, то полученные от сервера символы перевода строки должны преобразовываться в теги <br>.

Проверка 2: Если клиент преобразует получаемый от сервера текст в какую-то разметку, то все полученные данные должны экранироваться.
Если клиент использует HTML, то он должен экранировать три символа: амперсанд, меньше и больше. Так, в предыдущем пункте должен быть текст br, окружённый символами "меньше" и "больше", а в тексте далее должен быть явно виден символ "амперсанд" и не должно быть символа "больше": &gt;.

Проверка 3: Эта строка отделена от предыдущей пустой строкой (т.е. есть два перевода строки).

Проверка 4: После запуска приложения пользователю не показывали какие-то диалоги.
Приложение само запросило с сервера список акторов, само выбрало в качестве активного первый (в конце концов, в большинстве случаев список будет состоять из одного пункта, а мы не хотим заставлять пользователя делать лишние действия) и само же открыло объект этого выбранного актора.

Проверка 5: Приложение выводит только заголовок, подзаголовок и атрибуты, присутствующие в шаблоне. В данном конкретном случае нигде не выведен тип объекта ("test").
Считаем, что приложение честно не выводит атрибуты, отсутствующие в шаблоне и не являющиеся заголовком или подзаголовком, и верим, что атрибут с кодом "type" не обрабатывается особым образом :)

Проверка 6: Ниже есть ссылка с именем "Продолжить", ведущая на следующий тест. Приложение по нажатию на эту ссылку должно перейти к следующему объекту.

[Продолжить](babcom:test' || v_test_num || ')')
  );

  -- Форматирование

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Форматирование.
Markdown — формат, который все реализуют по-разному, поэтому мы не требуем, чтобы все сложные случаи обрабатывались одинаково.
Также клиенты могут просто использовать библиотеки и поддерживать какие-то возможности, не описанные в нашем документе. Их мы тоже не тестируем :grinning:

Проверка 1: Слово *italic* должно быть наклонным, фраза _italic phase_ — тоже.
Проверка 2: Начертание слова **жирный** должно отличаться большей насыщенностью линий, как и начертание фразы __жирный текст__.
Проверка 3: Вложенное форматирование также должно обрабатываться правильно: ***жирное** слово внутри наклонного текста*, __*наклонное* слово внутри жирного текста__.
Проверка 4: И, конечно же, ~~зачёркнутое~~ слово.
Проверка 5: Наконец, на ссылки форматирование тоже должно распространяться. Так, ссылка "Далее" должна быть жирной.

**[Продолжить](babcom:test' || v_test_num || ')**')
  );

  -- Несколько атрибутов в группе

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_description_attr_id integer;
    v_next_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'description', 'normal', 'full', true)
    returning id into v_description_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'next', 'normal', 'full', true)
    returning id into v_next_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s", "%s"]}',
          v_test_prefix || 'group',
          v_test_prefix || 'description',
          v_test_prefix || 'next')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (
      v_test_id,
      v_description_attr_id,
      to_jsonb(text
'Проверяем, как обрабатывается несколько атрибутов в одной группе.')
    ),
    (
      v_test_id,
      v_next_attr_id,
      to_jsonb(text
'**Проверка:** Эта строка находится в новом атрибуте. Она должна быть отделена от предыдущей, причём желательно, чтобы это разделение было визуально отлично от обычного начала новой строки.

[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Вывод чисел

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_description_attr_id integer;
    v_int_attr_id integer;
    v_double_attr_id integer;
    v_next_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'description', 'normal', 'full', true)
    returning id into v_description_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'integer', 'normal', 'full', true)
    returning id into v_int_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'double', 'normal', 'full', true)
    returning id into v_double_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'next', 'normal', 'full', true)
    returning id into v_next_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s", "%s", "%s", "%s"]}',
          v_test_prefix || 'group',
          v_test_prefix || 'description',
          v_test_prefix || 'integer',
          v_test_prefix || 'double',
          v_test_prefix || 'next')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (
      v_test_id,
      v_description_attr_id,
      to_jsonb(text
'Проверяем вывод нетекстовых атрибутов.

**Проверка:** Ниже выведены числа -42 и 0.0314159265 (именно так, а не в экспоненциальной записи!).')
    ),
    (v_test_id, v_int_attr_id, jsonb '-42'),
    (v_test_id, v_double_attr_id, jsonb '0.0314159265'),
    (
      v_test_id,
      v_next_attr_id,
      to_jsonb('[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Описания значения атрибутов

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_description_attr_id integer;
    v_int_attr_id integer;
    v_double_attr_id integer;
    v_string_attr_id integer;
    v_next_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'description', 'normal', 'full', true)
    returning id into v_description_attr_id;

    insert into data.attributes(code, value_description_function, type, card_type, can_be_overridden)
    values(v_test_prefix || 'integer', 'test_project.test_value_description_function', 'normal', 'full', true)
    returning id into v_int_attr_id;

    insert into data.attributes(code, value_description_function, type, card_type, can_be_overridden)
    values(v_test_prefix || 'double', 'test_project.test_value_description_function', 'normal', 'full', true)
    returning id into v_double_attr_id;

    insert into data.attributes(code, value_description_function, type, card_type, can_be_overridden)
    values(v_test_prefix || 'string', 'test_project.test_value_description_function', 'normal', 'full', true)
    returning id into v_string_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'next', 'normal', 'full', true)
    returning id into v_next_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s", "%s", "%s", "%s", "%s"]}',
          v_test_prefix || 'group',
          v_test_prefix || 'description',
          v_test_prefix || 'integer',
          v_test_prefix || 'double',
          v_test_prefix || 'string',
          v_test_prefix || 'next')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (
      v_test_id,
      v_description_attr_id,
      to_jsonb(text
'Проверяем вывод описаний значений атрибутов.

**Проверка:** Ниже выведены строки "минус сорок два", "π / 100" и "∫x dx = ½x² + C".')
    ),
    (v_test_id, v_int_attr_id, jsonb '-42'),
    (v_test_id, v_double_attr_id, jsonb '0.0314159265'),
    (v_test_id, v_string_attr_id, jsonb '"integral"'),
    (
      v_test_id,
      v_next_attr_id,
      to_jsonb('[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Описания значения атрибутов с форматированием

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_description_attr_id integer;
    v_int1_attr_id integer;
    v_int2_attr_id integer;
    v_next_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'description', 'normal', 'full', true)
    returning id into v_description_attr_id;

    insert into data.attributes(code, value_description_function, type, card_type, can_be_overridden)
    values(v_test_prefix || 'integer1', 'test_project.test_value_description_function', 'normal', 'full', true)
    returning id into v_int1_attr_id;

    insert into data.attributes(code, value_description_function, type, card_type, can_be_overridden)
    values(v_test_prefix || 'integer2', 'test_project.test_value_description_function', 'normal', 'full', true)
    returning id into v_int2_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'next', 'normal', 'full', true)
    returning id into v_next_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s", "%s", "%s", "%s"]}',
          v_test_prefix || 'group',
          v_test_prefix || 'description',
          v_test_prefix || 'integer1',
          v_test_prefix || 'integer2',
          v_test_prefix || 'next')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (
      v_test_id,
      v_description_attr_id,
      to_jsonb(text
'Проверяем вывод описаний значений атрибутов с форматированием.

**Проверка:** Ниже выведена жирная строка "один" и наклонная строка "два".')
    ),
    (v_test_id, v_int1_attr_id, jsonb '1'),
    (v_test_id, v_int2_attr_id, jsonb '2'),
    (
      v_test_id,
      v_next_attr_id,
      to_jsonb('[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Несколько групп

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_description_attr_id integer;
    v_next_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'description', 'normal', 'full', true)
    returning id into v_description_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'next', 'normal', 'full', true)
    returning id into v_next_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s"]}',
          v_test_prefix || 'group1',
          v_test_prefix || 'description')::jsonb);
    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s"]}',
          v_test_prefix || 'group2',
          v_test_prefix || 'next')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (
      v_test_id,
      v_description_attr_id,
      to_jsonb(text
'Теперь мы проверяем, как обрабатывается несколько групп.')
    ),
    (
      v_test_id,
      v_next_attr_id,
      to_jsonb(text
'**Проверка:** Эта строка находится в новой группе. Должно быть явно видно, где закончилась предыдущая группа и началась новая.

[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Группы с именем

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_description_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'description', 'normal', 'full', true)
    returning id into v_description_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "name": "Короткое имя группы", "attributes": ["%s"]}',
          v_test_prefix || 'group',
          v_test_prefix || 'description')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (
      v_test_id,
      v_description_attr_id,
      to_jsonb(text
'**Проверка:** У этой группы есть имя. Мы должны видеть текст "Короткое имя группы".

[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Имена у групп и атрибутов

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_short_attr_id integer;
    v_long_attr_id integer;
    v_short_value_attr_id integer;
    v_long_value_descr_attr_id integer;
    v_next_attr_id integer;
  begin
    insert into data.attributes(code, name, type, card_type, can_be_overridden)
    values(v_test_prefix || 'short_name', 'Атрибут 1', 'normal', 'full', true)
    returning id into v_short_attr_id;

    insert into data.attributes(code, name, type, card_type, can_be_overridden)
    values(v_test_prefix || 'long_name', 'Атрибут с очень длинным именем, которое нельзя так просто обрезать — оно очень важно для понимания назначения значения, его смысла, глубинной сути, места во вселенной и связи со значениями других атрибутов', 'normal', 'full', true)
    returning id into v_long_attr_id;

    insert into data.attributes(code, name, type, card_type, can_be_overridden)
    values(v_test_prefix || 'short_name_value', 'Атрибут 3', 'normal', 'full', true)
    returning id into v_short_value_attr_id;

    insert into data.attributes(code, name, value_description_function, type, card_type, can_be_overridden)
    values(v_test_prefix || 'long_name_value_description', 'Ещё один атрибут с длинным именем, которое почти наверняка не поместится в одну строку на современных телефонах', 'test_project.test_value_description_function', 'normal', 'full', true)
    returning id into v_long_value_descr_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'next', 'normal', 'full', true)
    returning id into v_next_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "name": "Тестовые данные", "attributes": ["%s", "%s", "%s", "%s", "%s"]}',
          v_test_prefix || 'group',
          v_test_prefix || 'short_name',
          v_test_prefix || 'long_name',
          v_test_prefix || 'short_name_value',
          v_test_prefix || 'long_name_value_description',
          v_test_prefix || 'next')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (
      v_test_id,
      v_description_attribute_id,
      to_jsonb(text
'Теперь имя будет и у группы, и у её атрибутов.

**Проверка 1:** Ниже есть ещё одна группа с именем "Тестовые данные".
**Проверка 2:** Первый атрибут в группе имеет имя "Атрибут 1" и не имеет значения и описания значения.
**Проверка 3:** Второй атрибут имеет длинное имя, которое не влезает в одну строку, начинается с "Атрибут с очень" и не имеет значения и описания значения.
**Проверка 4:** Третий атрибут имеет имя "Атрибут 3" и значение "100".
**Проверка 5:** Четвёртый атрибут имеет имя, начинающееся с "Ещё один атрибут" и также не влезающее в одну строку. Атрибут имеет довольно длинное описание значения, начинающееся с "Lorem ipsum".
**Проверка 6:** Слово ipsum должно быть жирным.
**Проверка 7:** Все атрибуты идут именно в указанном порядке.')
    ),
    (v_test_id, v_short_attr_id, jsonb 'null'),
    (v_test_id, v_long_attr_id, jsonb 'null'),
    (v_test_id, v_short_value_attr_id, jsonb '100'),
    (v_test_id, v_long_value_descr_attr_id, jsonb '"lorem ipsum"'),
    (
      v_test_id,
      v_next_attr_id,
      to_jsonb('[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Скроллирование

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Скроллинг.

Ниже представлен большой текст, который гарантированно не войдёт на экран. Клиент должен уметь скроллировать содержимое объекта, чтобы пользователь мог ознакомиться со всей информацией. Читать текст ниже не обязательно, просто промотайте до кнопки "Продолжить" :)

Человечество – то, что описывает и определяет Солнечную Систему в 24-ом веке. Можно было бы возразить, что планеты вращались по своим орбитам задолго до появления Человечества и продолжат вращаться много позже его исчезновения, а Солнце и вовсе будет светить практически вечно... Но это был бы пустой звук – всё равно что сообщить, что вода мокрая, а горизонт событий недостижим. Без Человека Солнечная Система оставалась бы лишь горсткой камней вокруг огненного шара.
В начале 22-го века Человечество вырвалось с родной планеты и заполонило пространство вокруг. И теперь, спустя всего 200 лет, трудно найти точку в космосе, не затронутую интересами Человека, его действием, волей или мыслью. От солнечных обсерваторий на Меркурии до станций исследования глубокого космоса за орбитой Сатурна – везде есть Человек и его творения.
Однако что есть Человек и что есть Человечество? Так ли едино то общество, которое мы называем этим словом? Так ли похожи друг на друга те, кто его составляет? Традиционалисты скажут: “нет”. Глобалисты скажут: “да”.
Пожалуй, по-настоящему единым человеческое общество было в начале 22-го века. Новый мировой порядок, установленный на Земле, в кратчайшие сроки – менее 50 лет – позволил избавить планету от голода, низкого уровня жизни и даже войн. Политика толерантности, провозглашённая на всей планете после 25-летнего глобального кризиса (называемого также Третьей мировой или Террористической войной), стала краеугольным камнем нового общественного устройства. 
Технический прогресс позволил распределить блага, ранее доступные только “золотому” миллиарду, среди всего населения. Отмена национальных государств и границ высвободила огромные ресурсы, которые до сих пор тратились на поддержание суверенитетов – армию, взаимное налогообложение и т.д.
В конце концов принятие Закона о до-гражданах остановило социально-финансовую гонку, заложенную ещё англо-саксонским доминированием. Право решать за всех перешло к самым активным и ответственным, а не богатым и знаменитым. Остальным же гарантировали пожизненные социальные блага.
Именно это общество смогло осуществить давнюю мечту Человечества – космическую экспансию. Началом её можно считать создание в 2130-м году колонии на Марсе. В отличие от научной станции, к тому моменту существовавшей на красной планете уже почти 100 лет, колония должна была стать крупным, населенным, индустриально развитым, самодостаточным форпостом Человечества.
Идею широко поддержали на Земле. Вслед за первопроходцами сотни тысяч людей вызвались покинуть родной дом и спокойную жизнь ради тяжелого труда на благо всей Человеческой цивилизации.
Менее чем за 30 лет население Марса увеличилось до нескольких миллионов и продолжало стремительно расти. Поддерживаемые прямыми субсидиями ООН, крупные корпорации активно строили на Марсе заводы, рекрутировали и вывозили рабочих с семьями, организовывали для них инфраструктуру. В течение каких-то десятков лет на другой планете создали крупное индустриальное общество. И вскоре это обернулось проблемой.
Марсианская колония разрослась стремительно – прежде всего, благодаря энтузиастам, её строившим. Они оказались людьми совершенно иного склада, непохожими на большинство землян. Стойкие, целеустремленные, горящие идеей обустройства новой планеты. Они готовы были жить и трудиться в тяжелейших психологических и физических условиях: при постоянной опасности погибнуть, минимальных социальных благах, нехватке воды и еды. Неудивительно, что такими людьми оказалось почти невозможно управлять извне.
Пока на Земле разбивали парки на месте бывших заводов и объявляли начало Века экологии, Марсиане – да, теперь у них было право так называться – в поту и грязи строили свой новый мир. Было наивно ожидать, что они строят его для удобно расположившихся на Земле “зрителей”. Ещё наивнее было не обращать внимания на растущую напряженность.
Первое массовое выступление за независимость Марса вспыхнуло всего через 30 лет после основания колонии. Ещё через 30 лет подобные выступления переросли в настоящую угрозу. А в 2197-м началась Первая война Марса за независимость.
Восстание было организовано нео-коммунистической партией Марса. Как ни странно, древние к тому моменту идеи оказались близки тысячам рабочих на красной планете. Самим определять свою жизнь. Стремиться к совершенствованию себя и мира вокруг, а не к бесцельному, сытому и тупому существованию до-граждан Земли. Сначала в движении доминировали гуманистические воззрения: Марсиане стремились к новому человеческому обществу, где править будет мысль, а не удовлетворение плотских нужд. Но после первой волны реакции, запретов и арестов инициативу перехватили приверженцы силовых мер и вооруженной борьбы.
Конечно же, и на Земле нашлись те, кто поддержал марсианское восстание. Видимо, это кроется в самой сути Человека: едва появляется шанс реализовать свои амбиции, как все прочие ценности становятся вторичными. Возможность создать собственную империю на Марсе расколола общество Земли. Закон о Новом порядке никто не отменял – миллиарды до-граждан даже ничего не заметили, но элита Земли вступила в эру нового противоборства.
Первая война за независимость была подавлена. Земля ввела войска, бунтовщиков арестовали, оружие изъяли. Но это была лишь первая вспышка – загасить пламя поднимающегося движения Земляне не смогли. Более двадцати лет ООН пыталась контролировать политику и экономику Марса, закрывать верфи, принуждать пользоваться только земными кораблями. На пропаганду идеи Единого Человечества были потрачены огромные ресурсы. Безуспешно.
Постоянно растущее сопротивление, приводящее к всё новым и новым жертвам, всё ещё можно можно было бы подавить силой. Но, разрываемая множеством внутренних течений, ООН на это не решилась. Слишком велики были бы потери для общества, которое не видело большой крови уже сто с лишним лет.
Ситуация разрешилась удивительным образом. Марсианин Соломон Эпштейн практически случайно пришёл к изобретению нового типа двигателя для космических кораблей. Обладая в тысячи раз большей эффективностью, новый двигатель сделал доступным для исследования и колонизации дальние рубежи Солнечной Системы. Будучи патриотом, Соломон посмертно подарил своё изобретение всем Марсианам.
Построенные на скорую руку, корабли с двигателем Эпштейна показывали такое преимущество над лучшими кораблями Земли, что становилось очевидно: эта технология изменит всё… И Земля не могла её упустить. В обмен на признание независимости Марса, как многие тогда считали – формальное, земные ученые получили полный доступ к исследованием Эпштейна.
Эти события имели два последствия. 
С одной стороны, на карте Человечества вновь появились два независимых лагеря. По историческим причинам недружественные друг другу, но чрезвычайно взаимо-зависимые. Пришлось извлечь из архивов и сдуть пыль с таких давно забытых понятий как “геополитика” и “гонка вооружений”.
С другой - обеим сторонам стал доступен дальний космос, а вместе с ним и пояс астероидов. Зачем добывать полезные ископаемые, выискивая их по крупице и тратя огромные средства на разработку, транспортировку и инфраструктуру на планете? Ведь теперь их можно просто находить в огромных глыбах, сканируя пространство спектроскопом, а затем разгонять в сторону Земли или Марса. Всех расходов – заселить несколько астероидов в ключевых точках Пояса.
И всё же, самым важным последствием “революции Эпштейна” стал “Исход”. Потрясающая простота и дешевизна двигателя сделали космос доступным каждому, у кого хватало духу пуститься в такое путешествие. Внезапно тысячи людей, конструируя корабли из старых транспортных баржей (а то и вовсе из бочек), ринулись в небо, опережая даже экспедиции, посланные в Пояс корпорациями.
Все те, кто не смог смириться ни с одним государственным строем, и составили основу самого молодого, уникального общества в составе Человечества – общества астероидян.
Крупные астероиды – Церера, Веста, Паллада, Европа, Эрос – быстро стали центрами новой цивилизации. Интересы Земли и Марса, военные и экономические, плотно перемешивались здесь с новой культурой – “варевом” из тысячи учений, верований и идей. Наверное, каждый, кто когда-то покинул поверхность одной из планет, принес сюда что-то свое.
Искатели приключений, жаждущие легкой наживы, мечтатели, строители собственных вероучений и империй, политические беженцы и просто путешественники смешивались с военными Земли и Марса, пилотами дальних транспортов и наёмными работниками корпораций.
Слишком далеко, чтобы попасть под полный контроль двух ключевых игроков человеческого мира. Слишком близко, чтобы не считаться с ними совсем. Слишком независимые по своему характеру – слишком зависимые из-за поставок ресурсов и обеспечения.
Тысячи маленьких станций и кораблей, снующих между астероидами. Бесконечные стычки из-за интересов, убеждений или банальной неприязни. Земному и Марсианскому правительствам, в спешке поделившим космос на зоны влияния, оставалось только притворяться, что они как-то контролируют весь этот рой.
Покорив новые пространства, люди строят и новое общество, опираясь на собственные принципы, исходящие из глубины их непокорной природы. Они сражаются за них, терпят лишения и рискуют, отрекаются от старого и видят надежду даже там, где её не может быть. Но именно так и только так совершается настоящая экспансия. Так и только так люди делают будущее настоящим, записывая, строчка за строчкой, историю нового человечества – Хомо Галактикус.

[Продолжить](babcom:test' || v_test_num || ')')
  );

  -- Группа только с действиями:
  -- - Выводятся в правильном порядке
  -- - Действие без имени и с именем
  -- - Заблокированное действие и обычное

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_next_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'next', 'normal', 'full', true)
    returning id into v_next_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "actions": ["%s", "%s", "%s", "%s"]}',
          v_test_prefix || 'group1',
          v_test_prefix || 'unnamed',
          v_test_prefix || 'named',
          v_test_prefix || 'unnamed_disabled',
          v_test_prefix || 'named_disabled')::jsonb);
    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s"]}',
          v_test_prefix || 'group2',
          v_test_prefix || 'next')::jsonb);

    insert into data.actions(code, function)
    values('do_nothing', 'test_project.do_nothing_action');

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.simple_actions_generator"'),
    (
      v_test_id,
      v_description_attribute_id,
      to_jsonb(text
'Ниже выведена группа, в которой нет атрибутов, только действия. Тест проверяет только отображение действий — все активные действия не имеют параметров, подтверждений, ничего не делают кроме генерации сообщения *ok*.
Возвращается пять действий, но в шаблоне присутствует только четыре.

**Проверка 1:** Первым идёт действие без имени, затем с именем "Действие", затем снова действие без имени, а в самом конце — с именем "Заблокированное действие".
**Проверка 2:** Последние два действия заблокированы — отличаются внешне и не могут быть выполнены (например, кнопки не нажимаются).
**Проверка 3:** Выведено только четыре действия.')
    ),
    (
      v_test_id,
      v_next_attr_id,
      to_jsonb('[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Действия после атрибутов

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_next_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'next', 'normal', 'full', true)
    returning id into v_next_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s"]}',
          v_test_prefix || 'group',
          v_test_prefix || 'next')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.simple_action_generator"'),
    (
      v_test_id,
      v_description_attribute_id,
      to_jsonb(text
'В этой группе есть и атрибут, и действие.

**Проверка:** Действие идёт после данного текста.')
    ),
    (
      v_test_id,
      v_next_attr_id,
      to_jsonb('[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Действие и атрибут имеют одинаковый код

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_action_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'action', 'normal', 'full', true)
    returning id into v_action_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "actions": ["%s"]}',
          v_test_prefix || 'group1',
          v_test_prefix || 'action')::jsonb);
    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s"]}',
          v_test_prefix || 'group2',
          v_test_prefix || 'action')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.object_action_generator"'),
    (
      v_test_id,
      v_description_attribute_id,
      to_jsonb(text
'В этом тесте есть атрибуты и действия с совпадающими кодами, они должны обрабатываться независимо.

**Проверка 1:** В следующей группе есть только действие.
**Проверка 2:** В последней группе есть только ссылка на следующий тест.')
    ),
    (
      v_test_id,
      v_action_attr_id,
      to_jsonb('[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Объект с заголовком

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_title_attribute_id, jsonb '"Jabberwocky"'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Атрибуты *title* и *subtitle* не входят в шаблон и должны обрабатываться клиентом особым образом.

**Проверка:** У данного объекта есть заголовок "Jabberwocky".

[Продолжить](babcom:test' || v_test_num || ')')
  );

  -- Объект с заголовком и подзаголовком

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_title_attribute_id, jsonb '"Паллада"'),
  (v_test_id, v_subtitle_attribute_id, jsonb '"Ролевая игра"'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'**Проверка:** У данного объекта помимо заголовка есть ещё и подзаголовок "Ролевая игра".

[Продолжить](babcom:test' || v_test_num || ')')
  );

  -- Объект с длинным заголовком и длинным подзаголовком

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_title_attribute_id, jsonb '"Сила притяжения: Паллада. Ролевая игра живого действия в жанре научной фантастики от мастерской группы White Star. Будет проходить 8-10 марта 2019 года на базе \"Спартанец\" под Новосибирском. Источники: сериал Expanse, книги Дж. Кори, Лема, Стругацких, Хайнлайна..."'),
  (v_test_id, v_subtitle_attribute_id, jsonb '"Это история о конфликте близкородственных культур, совсем недавно бывших единым целым. О том, как некогда единая цивилизация с иллюзией общего будущего оказывается разделённой на три различных вектора. Это игра о разных взглядах в Завтра и о корнях, которые всё еще прочно связывают все стороны конфликта. О попытках найти общий язык при острой потребности оставаться независимыми. И в каком-то смысле — это игра об отцах и детях. О праве новых поколений на самоопределение, развитие и свободу выбора собственного пути и об их надежде сохранить связь с истоками."'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Предполагается, что заголовок и подзаголовок — однострочники. Заголовок выводится крупным кеглем, а подзаголовок под ним — кеглем меньше. Возможно, даже другим шрифтом :)
Экраны телефонов у всех разные, так что даже относительно короткие тексты могут не войти. Такие тексты не нужно скроллировать по горизонтали или выводить в несколько строк, достаточно просто обрезать.

**Проверка:** У данного объекта и заголовок обрезаны.

[Продолжить](babcom:test' || v_test_num || ')')
  );

  -- Действие без подтверждения и параметров, params null

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  insert into data.actions(code, function, default_params)
  values(
    'next_action_with_null_params',
    'test_project.next_action_with_null_params',
    format('{"object_code": "%s"}', 'test' || v_test_num)::jsonb);
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.next_action_with_null_params_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Начинаем проверять обработку действий.
Атрибут *params* должен передаваться в неизменном виде. В действии ниже атрибут *params* равен *null*.

**Проверка 1:** Действие ниже перейдёт к следующему объекту.')
  );

  -- Действие без подтверждения и параметров, params - объект

  insert into data.actions(code, function)
  values('next_action_with_object_params', 'test_project.next_action_with_object_params');

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.next_action_with_object_params_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Теперь атрибут *params* является объектом.

**Проверка 1:** Действие ниже перейдёт к следующему объекту.')
  );

  -- Действие без подтверждения и параметров, params - массив

  insert into data.actions(code, function)
  values('next_action_with_array_params', 'test_project.next_action_with_array_params');

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.next_action_with_array_params_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'И, наконец, атрибут *params* является массивом.
Если этот тест и предыдущие два сработали, то считаем, что клиент честно передаёт *params* в неизменном виде, а не сделал специальную обработку null''а, объекта и массива :)

**Проверка 1:** Действие ниже перейдёт к следующему объекту.')
  );

  -- Действие с подтверждением

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.next_action_with_warning_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Действия с подтверждениями.

**Проверка 1:** По нажатию на кнопку ниже появляется диалог текстом "Вы действительно хотите перейти к следующему объекту?" и кнопками "ОК" и "Отмена".
**Проверка 2:** По нажатию на кнопку "Отмена" диалог закрывается и более ничего не происходит.
**Проверка 3:** По нажатию на кнопку "ОК" происходит переход к следующему тесту.')
  );

  -- Действие со строковым параметром

  insert into data.actions(code, function)
  values('next_action_with_text_user_param', 'test_project.next_action_with_text_user_param');

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.next_action_with_text_user_param_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Действие со строковым параметром.

**Проверка 1:** По нажатию на кнопку ниже появляется форма с именем параметра "Текстовая строка", полем для ввода строки и кнопками "ОК" и "Отмена".
**Проверка 2:** По нажатию на кнопку "Отмена" форма закрывается и более ничего не происходит.
**Проверка 3:** В поле можно ввести только одну строку, Enter не создаёт новую строку, а отправляет форму.
В варианте для мобильных приложений — справа внизу у клавиатуры есть значок "Отправить форму" и нет значка перевода строки.
**Проверка 4:** Вставка текста с переводами строк из буфера обмена не создаёт новые строки.
**Проверка 5:** По нажатию на кноку "ОК" происходит переход к следующему тесту.')
  );

  -- Действие с текстовым многострочным параметром

  insert into data.actions(code, function)
  values('next_action_with_multiline_user_param', 'test_project.next_action_with_multiline_user_param');

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.next_action_with_multiline_user_param_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Действие с многострочным текстовым параметром.

**Проверка:** В поле можно ввести несколько строк текста.')
  );

  -- Действие, принимающее в качестве параметра целое число

  insert into data.actions(code, function)
  values('next_action_with_integer_user_param', 'test_project.next_action_with_integer_user_param');

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.next_action_with_integer_user_param_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Действие, принимающее в качестве параметра целое число.
Здесь и далее: клиент может позволять вводить в поля значения, не удовлетворяющие ограничениям. Это может быть удобно, например, для вставки текста из буфера обмена и последующего редактирования значения.

**Проверка 1:** Кнопка "ОК" формы заблокирована и разблокируется только после ввода корректного целого числа.
**Проверка 2:** Как только поле ввода перестаёт содержать целое число, кнопка "ОК" снова блокируется.
**Проверка 3:** Пользователю сообщают, почему кнопка "ОК" заблокирована.')
  );

  -- Действие, принимающее в качестве параметра число с плавающей запятой

  insert into data.actions(code, function)
  values('next_action_with_double_user_param', 'test_project.next_action_with_double_user_param');

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.next_action_with_double_user_param_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Действие, принимающее в качестве параметра число с плавающей запятой.
Клиент вправе как разрешить, так и запретить ввод чисел в экспоненциальной записи.

**Проверка 1:** Кнопка "ОК" формы заблокирована и разблокируется только после ввода корректного числа (целого или с плавающей запятой).
**Проверка 2:** Как только поле ввода перестаёт содержать корректное число, кнопка "ОК" снова блокируется.
**Проверка 3:** Пользователю сообщают, почему кнопка "ОК" заблокирована.')
  );

  -- todo прочие тесты на действия:
  --   - с ограничениями
  --     - \n - один символ, emoji - тоже, модификаторы - на усмотрение
  --   - с min = max
  --   - с длиной 0
  --   - со значениями по умолчанию
  --   - несколько параметров
  --   - с параметрами и предупреждением

  -- Тест на автоматическую смену актора по действию

  insert into data.actions(code, function) values
  ('login', 'test_project.login_action'),
  ('diff', 'test_project.diff_action');

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.login_action_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'По действию ниже произойдёт изменение списка доступных акторов.

**Проверка:** По действию происходит открытие следующего теста.')
  );

  -- И далее в предыдущем тесте проверки на:
  --  - изменение атрибута, заголовка и действия по явному действию
  --  - удаление и добавление атрибутов
  --  - удаление действия из шаблона

  -- todo прочие тесты на изменения объекта

  v_test_num := v_test_num + 3;

  -- Вывод пустого списка

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_content_attribute_id, jsonb '[]'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (v_test_id, v_subtitle_attribute_id, jsonb '"Пустые списки"'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Объекты с пустыми списками должны отличаться от объектов без списков.

**Проверка:** В самом низу мы видим какую-то заглушку, которая говорит нам, что тут список вроде бы и есть, но его нет.

[Продолжить](babcom:test' || v_test_num || ')')
  );

  -- Вывод списка

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_full_card_function_attribute_id, jsonb '"test_project.simple_list_generator"'),
  (v_test_id, v_list_actions_function_attribute_id, jsonb '"test_project.do_nothing_list_action_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (v_test_id, v_subtitle_attribute_id, jsonb '"Непустые списки"'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Теперь мы возвращаем список из трёх элементов.
Атрибут со списком также возвращается, но не отображается, т.к. отсутствует в шаблоне, да и вообще является массивом.

**Проверка 1:** Ниже текста есть список с тремя элементами.
**Проверка 2:** Должно быть понятно, что это именно элементы списка, а не новые группы.
**Проверка 3:** Должно быть понятно, где заканчивается один элемент списка и начинается другой.
**Проверка 4:** Должно быть понятно, что элементы списка кликабельны.
**Проверка 5:** У первого элемента есть заголовок "Uno" и текст "Первый элемент списка".
**Проверка 6:** У второго элемента есть заголовок "Duo", подзаголовок "Второй элемент списка" и текст с дополнительными проверками.
**Проверка 7:** При выборе первого или второго элемента ничего не происходит.
**Проверка 8:** У третьего элемента есть заголовок "Далее" и какой-то текст.
**Проверка 9:** При выборе третьего элемента переходим к следующему тесту.')
  );

  -- И далее в предыдущем тесте проверки на:
  --  - diff c удалением списка
  --  - diff с добавлением списка
  --  - diff с удалением одного и удалением другого элемента списка

  insert into data.actions(code, function) values
  ('list_diff', 'test_project.list_diff_action');

  -- todo прочие тесты на списки

  v_test_num := v_test_num + 3;

  -- todo прочие тесты на списки
  -- todo и прочие тесты

  -- Финал!
  insert into data.objects(code) values('fin') returning id into v_test_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Пока что это все существующие тесты. Stay tuned!')
  );

  -- Заполним шаблон
  update data.params
  set value = jsonb_build_object('title', 'title', 'subtitle', 'subtitle', 'groups', to_jsonb(v_template_groups))
  where code = 'template';
end;
$$
language plpgsql;

-- drop function test_project.is_user_params_empty(jsonb);

create or replace function test_project.is_user_params_empty(in_user_params jsonb)
returns boolean
stable
as
$$
begin
  return in_user_params is null or in_user_params = jsonb 'null' or in_user_params = jsonb '{}';
end;
$$
language plpgsql;

-- drop function test_project.list_diff_action(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.list_diff_action(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_object_code text := json.get_string(in_params);
  v_object_id integer := data.get_object_id(v_object_code);
  v_test_state text := json.get_string(data.get_attribute_value(v_object_id, 'test_state'));
  v_changes jsonb := jsonb '[]';
begin
  assert test_project.is_user_params_empty(in_user_params);
  assert in_default_params is null;

  v_changes :=
    v_changes ||
    data.attribute_change2jsonb(
      'title',
      to_jsonb(
        test_project.next_code(
          json.get_string(
            data.get_attribute_value(
              v_object_id,
              'title',
              v_actor_id)))));
  if v_test_state = 'remove_list' then
    v_changes := v_changes || data.attribute_change2jsonb('subtitle', jsonb '"Тест добавления списка"');
    v_changes := v_changes || data.attribute_change2jsonb('content', jsonb '[]', v_actor_id);
    v_changes := v_changes || data.attribute_change2jsonb('test_state', jsonb '"add_list"');
    v_changes := v_changes || data.attribute_change2jsonb('description2', to_jsonb(text
'**Проверка 1:** Вместо удалённого списка появилась заглушка.
**Проверка 2:** По действию изменится заголовок, подзаголовок, описание, а также добавится два элемента списка.'));
  elsif v_test_state = 'add_list' then
    v_changes := v_changes || data.attribute_change2jsonb('subtitle', jsonb '"Тест изменения элемента списка"');
    v_changes := v_changes || data.attribute_change2jsonb('content', null, v_actor_id);
    v_changes := v_changes || data.attribute_change2jsonb('test_state', jsonb '"modify_list_element"');
    v_changes := v_changes || data.attribute_change2jsonb('description2', to_jsonb(text
'**Проверка 1:** Заглушка исчезла, вместо неё отображается два элемента списка.
**Проверка 2:** По действию изменится заголовок, подзаголовок, описание, а также изменится второй объект списка.'));
  elsif v_test_state = 'modify_list_element' then
    -- todo
  end if;

  assert data.change_current_object(in_client_id, in_request_id, v_object_id, v_changes);
end;
$$
language plpgsql;

-- drop function test_project.list_diff_action_generator(integer, integer);

create or replace function test_project.list_diff_action_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;
  return format('{"action": {"code": "list_diff", "name": "Далее", "disabled": false, "params": "%s"}}', v_object_code)::jsonb;
end;
$$
language plpgsql;

-- drop function test_project.login_action(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.login_action(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_title text := test_project.next_code(json.get_string(in_params));
  v_login_id integer;
  v_object_id integer;
begin
  perform data.get_active_actor_id(in_client_id);

  assert in_request_id is not null;
  assert test_project.is_user_params_empty(in_user_params);
  assert in_default_params is null;

  -- Создадим новый логин
  insert into data.logins
  default values
  returning id into v_login_id;

  -- Создадим тест
  insert into data.objects
  default values
  returning id into v_object_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_object_id, data.get_attribute_id('type'), jsonb '"test"'),
  (v_object_id, data.get_attribute_id('is_visible'), jsonb 'true'),
  (v_object_id, data.get_attribute_id('test_state'), jsonb '"state1"'),
  (v_object_id, data.get_attribute_id('actions_function'), jsonb '"test_project.diff_action_generator"'),
  (v_object_id, data.get_attribute_id('title'), to_jsonb(v_title)),
  (
    v_object_id,
    data.get_attribute_id('description'),
    to_jsonb(text
'Новый актор!

**Проверка 1:** Мы перешли к данному объекту автоматически, никакие списки не показывались.
**Проверка 2:** В списке акторов теперь красуется одинокий актор с заголовком "' || v_title || '"
**Проверка 3:** Действие ниже приводит к изменению описания данного объекта.')
  );

  -- Привяжем тест к логину
  insert into data.login_actors(login_id, actor_id)
  values(v_login_id, v_object_id);

  -- Заменим логин
  perform data.set_login(in_client_id, v_login_id);

  -- И отправим новый список акторов
  perform api_utils.process_get_actors_message(in_client_id, in_request_id);
end;
$$
language plpgsql;

-- drop function test_project.login_action_generator(integer, integer);

create or replace function test_project.login_action_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_title text := json.get_string(data.get_attribute_value(in_object_id, 'title', in_actor_id));
begin
  return format('{"action": {"code": "login", "name": "Далее", "disabled": false, "params": "%s"}}', v_title)::jsonb;
end;
$$
language plpgsql;

-- drop function test_project.next_action_with_array_params(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.next_action_with_array_params(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_array jsonb := json.get_array(in_params);
  v_array_len integer := jsonb_array_length(v_array);
  v_object_code text;
begin
  perform data.get_active_actor_id(in_client_id);

  assert in_request_id is not null;
  assert test_project.is_user_params_empty(in_user_params);
  assert in_default_params is null;

  assert v_array_len = 1;

  v_object_code := json.get_string(v_array->0);

  perform api_utils.create_open_object_action_notification(
    in_client_id,
    in_request_id,
    test_project.next_code(v_object_code));
end;
$$
language plpgsql;

-- drop function test_project.next_action_with_array_params_generator(integer, integer);

create or replace function test_project.next_action_with_array_params_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  return format('{"action": {"code": "next_action_with_array_params", "name": "Далее", "disabled": false, "params": ["%s"]}}', v_object_code)::jsonb;
end;
$$
language plpgsql;

-- drop function test_project.next_action_with_double_user_param(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.next_action_with_double_user_param(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_params);
begin
  perform data.get_active_actor_id(in_client_id);
  perform json.get_number(in_user_params, 'param');

  assert in_request_id is not null;
  assert in_default_params is null;

  perform api_utils.create_open_object_action_notification(
    in_client_id,
    in_request_id,
    test_project.next_code(v_object_code));
end;
$$
language plpgsql;

-- drop function test_project.next_action_with_double_user_param_generator(integer, integer);

create or replace function test_project.next_action_with_double_user_param_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  return format(
'{
  "action": {
    "code": "next_action_with_double_user_param",
    "name": "Далее",
    "disabled": false,
    "params": "%s",
    "user_params": [
      {
        "code": "param",
        "description": "Число",
        "type": "float",
        "restrictions": {}
      }
    ]
  }
}', v_object_code)::jsonb;
end;
$$
language plpgsql;

-- drop function test_project.next_action_with_integer_user_param(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.next_action_with_integer_user_param(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_params);
  v_param integer := json.get_integer(in_user_params, 'param');
begin
  perform data.get_active_actor_id(in_client_id);

  assert in_request_id is not null;
  assert in_default_params is null;

  perform api_utils.create_open_object_action_notification(
    in_client_id,
    in_request_id,
    test_project.next_code(v_object_code));
end;
$$
language plpgsql;

-- drop function test_project.next_action_with_integer_user_param_generator(integer, integer);

create or replace function test_project.next_action_with_integer_user_param_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  return format(
'{
  "action": {
    "code": "next_action_with_integer_user_param",
    "name": "Далее",
    "disabled": false,
    "params": "%s",
    "user_params": [
      {
        "code": "param",
        "description": "Целое число",
        "type": "integer",
        "restrictions": {}
      }
    ]
  }
}', v_object_code)::jsonb;
end;
$$
language plpgsql;

-- drop function test_project.next_action_with_multiline_user_param(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.next_action_with_multiline_user_param(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_params);
  v_param text := json.get_string(in_user_params, 'param');
begin
  perform data.get_active_actor_id(in_client_id);

  assert in_request_id is not null;
  assert in_default_params is null;

  perform api_utils.create_open_object_action_notification(
    in_client_id,
    in_request_id,
    test_project.next_code(v_object_code));
end;
$$
language plpgsql;

-- drop function test_project.next_action_with_multiline_user_param_generator(integer, integer);

create or replace function test_project.next_action_with_multiline_user_param_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  return format(
'{
  "action": {
    "code": "next_action_with_multiline_user_param",
    "name": "Далее",
    "disabled": false,
    "params": "%s",
    "user_params": [
      {
        "code": "param",
        "description": "Текстовый блок",
        "type": "string",
        "restrictions": {
          "multiline": true
        }
      }
    ]
  }
}', v_object_code)::jsonb;
end;
$$
language plpgsql;

-- drop function test_project.next_action_with_null_params(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.next_action_with_null_params(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_default_params, 'object_code');
begin
  perform data.get_active_actor_id(in_client_id);

  assert in_request_id is not null;
  assert in_params = jsonb 'null';
  assert test_project.is_user_params_empty(in_user_params);

  perform api_utils.create_open_object_action_notification(
    in_client_id,
    in_request_id,
    test_project.next_code(v_object_code));
end;
$$
language plpgsql;

-- drop function test_project.next_action_with_null_params_generator(integer, integer);

create or replace function test_project.next_action_with_null_params_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
begin
  perform data.get_object_code(in_object_id);
  assert in_actor_id is not null;

  return jsonb '{"action": {"code": "next_action_with_null_params", "name": "Далее", "disabled": false, "params": null}}';
end;
$$
language plpgsql;

-- drop function test_project.next_action_with_object_params(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.next_action_with_object_params(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_params, 'object_code');
begin
  perform data.get_active_actor_id(in_client_id);

  assert in_request_id is not null;
  assert test_project.is_user_params_empty(in_user_params);
  assert in_default_params is null;

  perform api_utils.create_open_object_action_notification(
    in_client_id,
    in_request_id,
    test_project.next_code(v_object_code));
end;
$$
language plpgsql;

-- drop function test_project.next_action_with_object_params_generator(integer, integer);

create or replace function test_project.next_action_with_object_params_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  return format('{"action": {"code": "next_action_with_object_params", "name": "Далее", "disabled": false, "params": {"object_code": "%s"}}}', v_object_code)::jsonb;
end;
$$
language plpgsql;

-- drop function test_project.next_action_with_text_user_param(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.next_action_with_text_user_param(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_params);
  v_param text := json.get_string(in_user_params, 'param');
begin
  perform data.get_active_actor_id(in_client_id);

  assert in_request_id is not null;
  assert in_default_params is null;
  assert position(E'\n' in v_param) = 0;

  perform api_utils.create_open_object_action_notification(
    in_client_id,
    in_request_id,
    test_project.next_code(v_object_code));
end;
$$
language plpgsql;

-- drop function test_project.next_action_with_text_user_param_generator(integer, integer);

create or replace function test_project.next_action_with_text_user_param_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  return format(
'{
  "action": {
    "code": "next_action_with_text_user_param",
    "name": "Далее",
    "disabled": false,
    "params": "%s",
    "user_params": [
      {
        "code": "param",
        "description": "Текстовая строка",
        "type": "string",
        "restrictions": {
          "multiline": false
        }
      }
    ]
  }
}', v_object_code)::jsonb;
end;
$$
language plpgsql;

-- drop function test_project.next_action_with_warning_generator(integer, integer);

create or replace function test_project.next_action_with_warning_generator(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  return format('{"action": {"code": "next_action_with_object_params", "name": "Далее", "warning": "Вы действительно хотите перейти к следующему объекту?", "disabled": false, "params": {"object_code": "%s"}}}', v_object_code)::jsonb;
end;
$$
language plpgsql;

-- drop function test_project.next_code(text);

create or replace function test_project.next_code(in_code text)
returns text
immutable
as
$$
declare
  v_prefix text := trim(trailing '0123456789' from in_code);
  v_suffix integer := substring(in_code from char_length(v_prefix) + 1)::integer;
begin
  return v_prefix || (v_suffix + 1)::text;
end;
$$
language plpgsql;

-- drop function test_project.next_or_do_nothing_list_action(integer, text, integer, integer);

create or replace function test_project.next_or_do_nothing_list_action(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_object_title text := test_project.next_code(json.get_string(data.get_attribute_value(in_object_id, 'title', v_actor_id)));
  v_list_object_title text := json.get_string_opt(data.get_attribute_value(in_list_object_id, 'title', v_actor_id), null);
  v_object_id integer;
  v_object_code text;
  v_content jsonb := jsonb '[]';
  v_login_id integer;
begin
  assert in_request_id is not null;

  if v_list_object_title = 'Далее' then
    -- Два элемента списка

    insert into data.objects
    default values
    returning id, code into v_object_id, v_object_code;

    v_content := v_content || to_jsonb(v_object_code);

    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_object_id, data.get_attribute_id('type'), jsonb '"list_object"'),
    (v_object_id, data.get_attribute_id('is_visible'), jsonb 'true'),
    (v_object_id, data.get_attribute_id('title'), jsonb '"One"'),
    (v_object_id, data.get_attribute_id('template'), jsonb '{"title": "title", "groups":[]}');

    insert into data.objects
    default values
    returning id, code into v_object_id, v_object_code;

    v_content := v_content || to_jsonb(v_object_code);

    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_object_id, data.get_attribute_id('type'), jsonb '"list_object"'),
    (v_object_id, data.get_attribute_id('is_visible'), jsonb 'true'),
    (v_object_id, data.get_attribute_id('title'), jsonb '"Two"'),
    (v_object_id, data.get_attribute_id('template'), jsonb '{"title": "title", "groups":[]}');

    -- И основной объект

    insert into data.objects
    default values
    returning id, code into v_object_id, v_object_code;

    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_object_id, data.get_attribute_id('type'), jsonb '"test"'),
    (v_object_id, data.get_attribute_id('test_state'), jsonb '"remove_list"'),
    (v_object_id, data.get_attribute_id('is_visible'), jsonb 'true'),
    (v_object_id, data.get_attribute_id('content'), v_content),
    (v_object_id, data.get_attribute_id('actions_function'), jsonb '"test_project.list_diff_action_generator"'),
    (v_object_id, data.get_attribute_id('list_element_function'), jsonb '"test_project.next_or_do_nothing_list_action"'),
    (v_object_id, data.get_attribute_id('title'), to_jsonb(v_object_title)),
    (v_object_id, data.get_attribute_id('subtitle'), jsonb '"Тест удаления списка"'),
    (v_object_id, data.get_attribute_id('template'), jsonb '{"title": "title", "subtitle": "subtitle", "groups": [{"code": "main", "attributes": ["description2"], "actions": ["action"]}]}'),
    (v_object_id, data.get_attribute_id('description2'), to_jsonb(text
'**Проверка:** По нажатию на кнопку "Далее" изменится заголовок, подзаголовок, описание объекта, а также удалится список!'));

    -- Создадим новый логин
    insert into data.logins
    default values
    returning id into v_login_id;

    -- Привяжем тест к логину
    insert into data.login_actors(login_id, actor_id)
    values(v_login_id, v_object_id);

    -- Заменим логин
    perform data.set_login(in_client_id, v_login_id);

    -- И отправим новый список акторов
    perform api_utils.process_get_actors_message(in_client_id, in_request_id);
  else
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;

-- drop function test_project.object_action_generator(integer, integer);

create or replace function test_project.object_action_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  return format('{"%s_action": {"code": "do_nothing", "name": "Не тыкай сюда!", "disabled": false, "params": null}}', v_object_code)::jsonb;
end;
$$
language plpgsql;

-- drop function test_project.simple_action_generator(integer, integer);

create or replace function test_project.simple_action_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
begin
  perform data.get_object_code(in_object_id);
  assert in_actor_id is not null;

  return jsonb '{"action": {"code": "do_nothing", "name": "Не тыкай сюда!", "disabled": false, "params": null}}';
end;
$$
language plpgsql;

-- drop function test_project.simple_actions_generator(integer, integer);

create or replace function test_project.simple_actions_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  return jsonb_build_object(
    v_object_code || '_unnamed',
    jsonb '{"code": "do_nothing", "disabled": false, "params": null}',
    v_object_code || '_named',
    jsonb '{"code": "do_nothing", "name": "Действие", "disabled": false, "params": null}',
    v_object_code || '_unnamed_disabled',
    jsonb '{"disabled": true}',
    v_object_code || '_named_disabled',
    jsonb '{"name": "Заблокированное действие", "disabled": true}',
    v_object_code || '_invisible',
    jsonb '{"code": "do_nothing", "name": "Невидимое действие", "disabled": false, "params": null}');
end;
$$
language plpgsql;

-- drop function test_project.simple_list_generator(integer, integer);

create or replace function test_project.simple_list_generator(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_content jsonb := data.get_attribute_value(in_object_id, 'content', in_actor_id);
  v_object_id integer;
  v_object_code text;
begin
  if v_content is not null then
    return;
  end if;

  v_content := jsonb '[]';

  -- Первый объект

  insert into data.objects
  default values
  returning id, code into v_object_id, v_object_code;

  v_content := v_content || to_jsonb(v_object_code);

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_object_id, data.get_attribute_id('type'), jsonb '"list_object"'),
  (v_object_id, data.get_attribute_id('is_visible'), jsonb 'true'),
  (v_object_id, data.get_attribute_id('title'), jsonb '"Uno"'),
  (v_object_id, data.get_attribute_id('template'), jsonb '{"title": "title", "groups": [{"code": "main", "attributes": ["description2"]}]}'),
  (v_object_id, data.get_attribute_id('description2'), jsonb '"Первый элемент списка"');

  -- Второй объект

  insert into data.objects
  default values
  returning id, code into v_object_id, v_object_code;

  v_content := v_content || to_jsonb(v_object_code);

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_object_id, data.get_attribute_id('type'), jsonb '"list_object"'),
  (v_object_id, data.get_attribute_id('is_visible'), jsonb 'true'),
  (v_object_id, data.get_attribute_id('title'), jsonb '"Duo"'),
  (v_object_id, data.get_attribute_id('subtitle'), jsonb '"Второй элемент списка"'),
  (v_object_id, data.get_attribute_id('attribute_with_description'), jsonb '"значение"'),
  (v_object_id, data.get_attribute_id('attribute'), jsonb '"значение"'),
  (v_object_id, data.get_attribute_id('template'), jsonb '{"title": "title", "subtitle": "subtitle", "groups": [{"code": "main", "attributes": ["description2"]}, {"code": "additional", "name": "Группа элемента списка", "attributes": ["short_card_attribute", "attribute_with_description", "attribute"], "actions": ["action"]}]}'),
  (v_object_id, data.get_attribute_id('description2'), to_jsonb(text
'**Проверка 1:** В этом объекте списка две группы.
**Проверка 2:** У второй группы есть имя "Группа элемента списка".
**Проверка 3:** Во второй группе есть три атрибута.
**Проверка 4:** У первого есть имя, но нет значения.
**Проверка 5:** У второго есть только описание значения.
**Проверка 6:** У третьего есть имя и значение.
**Проверка 7:** Под атрибутами есть действие.
**Проверка 8:** При выборе действия выполняется именно оно.'));

  -- Третий объект

  insert into data.objects
  default values
  returning id, code into v_object_id, v_object_code;

  v_content := v_content || to_jsonb(v_object_code);

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_object_id, data.get_attribute_id('type'), jsonb '"list_object"'),
  (v_object_id, data.get_attribute_id('is_visible'), jsonb 'true'),
  (v_object_id, data.get_attribute_id('title'), jsonb '"Далее"'),
  (v_object_id, data.get_attribute_id('template'), jsonb '{"title": "title", "groups": [{"code": "main", "attributes": ["description2"]}]}'),
  (v_object_id, data.get_attribute_id('description2'), jsonb '"Ничтоже сумняшеся выбираем этот элемент для перехода к следующему тесту"');

  -- Заполняем параметры оригинального объекта

  perform data.set_attribute_value(in_object_id, data.get_attribute_id('content'), v_content, null, in_actor_id);
  perform data.set_attribute_value(in_object_id, data.get_attribute_id('list_element_function'), jsonb '"test_project.next_or_do_nothing_list_action"', null, in_actor_id);
end;
$$
language plpgsql;

-- drop function test_project.test_value_description_function(integer, jsonb, data.card_type, integer);

create or replace function test_project.test_value_description_function(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
begin
  assert in_attribute_id is not null;
  assert in_actor_id is not null;

  if in_value = jsonb '-42' then
    return 'минус сорок два';
  elsif in_value = jsonb '1' then
    return '**один**';
  elsif in_value = jsonb '2' then
    return '*два*';
  elsif in_value = jsonb '"значение"' then
    return 'описание значения';
  elsif in_value = jsonb '"lorem ipsum"' then
    return 'Lorem **ipsum** dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.';
  elsif in_value = jsonb '0.0314159265' then
    return 'π / 100';
  elsif in_value = jsonb '"integral"' then
    return '∫x dx = ½x² + C';
  end if;

  assert false;
end;
$$
language plpgsql;

-- Creating tables

-- drop table data.actions;

create table data.actions(
  id integer not null generated always as identity,
  code text not null,
  function text not null,
  default_params jsonb,
  constraint actions_pk primary key(id),
  constraint actions_unique_code unique(code)
);

comment on column data.actions.function is 'Имя функции для выполнения действия. Функция вызывается с параметрами (client_id, request_id, params, user_params, default_params), где params - параметры, передаваемые на клиент и возвращаемые с него в неизменном виде, user_params - параметры, вводимые пользователем, default_params - параметры, прописанные в данной таблице. Функция должна либо бросить исключение, либо сгенерировать сообщение клиенту.';

-- drop table data.attribute_values;

create table data.attribute_values(
  id integer not null generated always as identity,
  object_id integer not null,
  attribute_id integer not null,
  value_object_id integer,
  value jsonb not null,
  start_time timestamp with time zone not null default clock_timestamp(),
  start_reason text,
  start_actor_id integer,
  constraint attribute_values_pk primary key(id),
  constraint attribute_values_value_object_check check((value_object_id is null) or (data.can_attribute_be_overridden(attribute_id) and data.is_instance(value_object_id)))
);

comment on column data.attribute_values.value_object_id is 'Объект, для которого переопределено значение атрибута. В случае, если видно несколько переопределённых значений, выбирается значение для объекта с наивысшим приоритетом.';

-- drop table data.attribute_values_journal;

create table data.attribute_values_journal(
  id integer not null generated always as identity,
  object_id integer not null,
  attribute_id integer not null,
  value_object_id integer,
  value jsonb not null,
  start_time timestamp with time zone not null,
  start_reason text,
  start_actor_id integer,
  end_time timestamp with time zone not null,
  end_reason text,
  end_actor_id integer,
  constraint attribute_values_journal_object_check check(data.is_instance(object_id)),
  constraint attribute_values_journal_pk primary key(id)
);

-- drop table data.attributes;

create table data.attributes(
  id integer not null generated always as identity,
  code text not null,
  name text,
  description text,
  type data.attribute_type not null,
  card_type data.card_type,
  value_description_function text,
  can_be_overridden boolean not null,
  constraint attributes_pk primary key(id),
  constraint attributes_unique_code unique(code)
);

comment on column data.attributes.card_type is 'Если null, то применимо ко всем типам карточек';
comment on column data.attributes.value_description_function is 'Имя функции для получения описания значения атрибута. Функция вызывается с параметрами (attribute_id, value, card_type, actor_id).
Функция не может изменять объекты базы данных, т.е. должна быть stable или immutable.';
comment on column data.attributes.can_be_overridden is 'Если false, то значение атрибута не может переопределяться для объектов';

-- drop table data.client_subscription_objects;

create table data.client_subscription_objects(
  id integer not null generated always as identity,
  client_subscription_id integer not null,
  object_id integer not null,
  index integer not null,
  is_visible boolean not null,
  constraint client_subscription_objects_index_check check(index > 0),
  constraint client_subscription_objects_object_check check(data.is_instance(object_id)),
  constraint client_subscription_objects_pk primary key(id),
  constraint client_subscription_objects_unique_csi_i unique(client_subscription_id, index) deferrable,
  constraint client_subscription_objects_unique_oi_csi unique(object_id, client_subscription_id)
);

-- drop table data.client_subscriptions;

create table data.client_subscriptions(
  id integer not null generated always as identity,
  client_id integer not null,
  object_id integer not null,
  constraint client_subscriptions_object_check check(data.is_instance(object_id)),
  constraint client_subscriptions_pk primary key(id),
  constraint client_subscriptions_unique_object_client unique(object_id, client_id)
);

-- drop table data.clients;

create table data.clients(
  id integer not null generated always as identity,
  code text not null,
  is_connected boolean not null,
  login_id integer,
  actor_id integer,
  constraint clients_actor_check check((actor_id is null) or data.is_instance(actor_id)),
  constraint clients_pk primary key(id),
  constraint clients_unique_code unique(code)
);

-- drop table data.jobs;

create table data.jobs(
  id integer not null generated always as identity,
  desired_time timestamp with time zone not null,
  function text not null,
  params jsonb,
  constraint jobs_pk primary key(id)
);

-- drop table data.log;

create table data.log(
  id integer not null generated always as identity,
  severity data.severity not null,
  event_time timestamp with time zone not null default clock_timestamp(),
  message text not null,
  actor_id integer,
  constraint log_actor_check check((actor_id is null) or data.is_instance(actor_id)),
  constraint log_pk primary key(id)
);

-- drop table data.login_actors;

create table data.login_actors(
  id integer not null generated always as identity,
  login_id integer not null,
  actor_id integer not null,
  constraint login_actors_actor_check check(data.is_instance(actor_id)),
  constraint login_actors_pk primary key(id),
  constraint login_actors_unique_login_actor unique(login_id, actor_id)
);

-- drop table data.logins;

create table data.logins(
  id integer not null generated always as identity,
  code text not null default (pgcrypto.gen_random_uuid())::text,
  constraint logins_pk primary key(id),
  constraint logins_unique_code unique(code)
);

-- drop table data.metrics;

create table data.metrics(
  id integer not null generated always as identity,
  type data.metric_type not null,
  value integer not null,
  constraint metrics_pk primary key(id),
  constraint metrics_unique_type unique(type)
);

-- drop table data.notifications;

create table data.notifications(
  id integer not null generated always as identity,
  code text not null default (pgcrypto.gen_random_uuid())::text,
  type data.notification_type not null,
  message jsonb not null,
  client_id integer,
  constraint notifications_client_check check((type = 'client_message'::data.notification_type) = (client_id is not null)),
  constraint notifications_pk primary key(id),
  constraint notifications_unique_code unique(code)
);

-- drop table data.object_objects;

create table data.object_objects(
  id integer not null generated always as identity,
  parent_object_id integer not null,
  object_id integer not null,
  intermediate_object_ids integer[],
  start_time timestamp with time zone not null default clock_timestamp(),
  start_reason text,
  start_actor_id integer,
  constraint object_objects_intermediate_object_ids_check check(intarray.uniq(intarray.sort(intermediate_object_ids)) = intarray.sort(intermediate_object_ids)),
  constraint object_objects_object_check check(data.is_instance(object_id)),
  constraint object_objects_parent_object_check check(data.is_instance(parent_object_id)),
  constraint object_objects_pk primary key(id)
);

comment on column data.object_objects.intermediate_object_ids is 'Список промежуточных объектов, через которые связан дочерний объект с родительским';

-- drop table data.object_objects_journal;

create table data.object_objects_journal(
  id integer not null generated always as identity,
  parent_object_id integer not null,
  object_id integer not null,
  intermediate_object_ids integer[],
  start_time timestamp with time zone not null,
  start_reason text,
  start_actor_id integer,
  end_time timestamp with time zone not null,
  end_reason text,
  end_actor_id integer,
  constraint object_objects_journal_pk primary key(id)
);

-- drop table data.objects;

create table data.objects(
  id integer not null generated always as identity,
  code text default (pgcrypto.gen_random_uuid())::text,
  type data.object_type not null default 'instance'::data.object_type,
  class_id integer,
  constraint objects_class_reference_check check((class_id is null) or ((type = 'instance'::data.object_type) and (not data.is_instance(class_id)))),
  constraint objects_pk primary key(id),
  constraint objects_unique_code unique(code)
);

-- drop table data.params;

create table data.params(
  id integer not null generated always as identity,
  code text not null,
  value jsonb not null,
  description text,
  constraint params_pk primary key(id),
  constraint params_unique_code unique(code)
);

-- Creating foreign keys

alter table data.attribute_values add constraint attribute_values_fk_attributes
foreign key(attribute_id) references data.attributes(id);

alter table data.attribute_values add constraint attribute_values_fk_objects
foreign key(object_id) references data.objects(id);

alter table data.attribute_values add constraint attribute_values_fk_start_actor
foreign key(start_actor_id) references data.objects(id);

alter table data.attribute_values add constraint attribute_values_fk_value_object
foreign key(value_object_id) references data.objects(id);

alter table data.attribute_values_journal add constraint attribute_values_journal_fk_attributes
foreign key(attribute_id) references data.attributes(id);

alter table data.attribute_values_journal add constraint attribute_values_journal_fk_end_actor
foreign key(end_actor_id) references data.objects(id);

alter table data.attribute_values_journal add constraint attribute_values_journal_fk_objects
foreign key(object_id) references data.objects(id);

alter table data.attribute_values_journal add constraint attribute_values_journal_fk_start_actor
foreign key(start_actor_id) references data.objects(id);

alter table data.attribute_values_journal add constraint attribute_values_journal_fk_value_object
foreign key(value_object_id) references data.objects(id);

alter table data.client_subscription_objects add constraint client_subscription_objects_fk_client_subscriptions
foreign key(client_subscription_id) references data.client_subscriptions(id);

alter table data.client_subscription_objects add constraint client_subscription_objects_fk_objects
foreign key(object_id) references data.objects(id);

alter table data.client_subscriptions add constraint client_subscriptions_fk_clients
foreign key(client_id) references data.clients(id);

alter table data.client_subscriptions add constraint client_subscriptions_fk_objects
foreign key(object_id) references data.objects(id);

alter table data.clients add constraint clients_fk_logins
foreign key(login_id) references data.logins(id);

alter table data.clients add constraint clients_fk_objects
foreign key(actor_id) references data.objects(id);

alter table data.log add constraint log_fk_objects
foreign key(actor_id) references data.objects(id);

alter table data.login_actors add constraint login_actors_fk_logins
foreign key(login_id) references data.logins(id);

alter table data.login_actors add constraint login_actors_fk_objects
foreign key(actor_id) references data.objects(id);

alter table data.notifications add constraint notifications_fk_clients
foreign key(client_id) references data.clients(id);

alter table data.object_objects add constraint object_objects_fk_object
foreign key(object_id) references data.objects(id);

alter table data.object_objects add constraint object_objects_fk_parent_object
foreign key(parent_object_id) references data.objects(id);

alter table data.object_objects add constraint object_objects_fk_start_actor
foreign key(start_actor_id) references data.objects(id);

alter table data.object_objects_journal add constraint object_objects_journal_fk_end_actor
foreign key(end_actor_id) references data.objects(id);

alter table data.object_objects_journal add constraint object_objects_journal_fk_object
foreign key(object_id) references data.objects(id);

alter table data.object_objects_journal add constraint object_objects_journal_fk_parent_object
foreign key(parent_object_id) references data.objects(id);

alter table data.object_objects_journal add constraint object_objects_journal_fk_start_actor
foreign key(start_actor_id) references data.objects(id);

alter table data.objects add constraint objects_fk_objects
foreign key(class_id) references data.objects(id);

-- Creating indexes

-- drop index data.attribute_values_idx_oi_ai;

create unique index attribute_values_idx_oi_ai on data.attribute_values(object_id, attribute_id) where (value_object_id is null);

-- drop index data.attribute_values_idx_oi_ai_voi;

create unique index attribute_values_idx_oi_ai_voi on data.attribute_values(object_id, attribute_id, value_object_id) where (value_object_id is not null);

-- drop index data.attribute_values_nuidx_oi_ai;

create index attribute_values_nuidx_oi_ai on data.attribute_values(object_id, attribute_id);

-- drop index data.client_subscriptions_idx_client;

create index client_subscriptions_idx_client on data.client_subscriptions(client_id);

-- drop index data.clients_idx_actor_id;

create index clients_idx_actor_id on data.clients(actor_id);

-- drop index data.jobs_idx_time;

create index jobs_idx_time on data.jobs(desired_time);

-- drop index data.notifications_idx_client_id;

create index notifications_idx_client_id on data.notifications(client_id);

-- drop index data.object_objects_idx_loi_goi;

create unique index object_objects_idx_loi_goi on data.object_objects(least(parent_object_id, object_id), greatest(parent_object_id, object_id)) where (intermediate_object_ids is null);

-- drop index data.object_objects_idx_oi;

create index object_objects_idx_oi on data.object_objects(object_id);

-- drop index data.object_objects_idx_poi_oi;

create unique index object_objects_idx_poi_oi on data.object_objects(parent_object_id, object_id) where (intermediate_object_ids is null);

-- drop index data.object_objects_idx_poi_oi_ioi;

create unique index object_objects_idx_poi_oi_ioi on data.object_objects(parent_object_id, object_id, intarray.uniq(intarray.sort(intermediate_object_ids))) where (intermediate_object_ids is not null);

-- drop index data.object_objects_nuidx_poi_oi;

create index object_objects_nuidx_poi_oi on data.object_objects(parent_object_id, object_id);

-- Creating triggers

-- drop trigger objects_trigger_after_insert on data.objects;

create trigger objects_trigger_after_insert
after insert
on data.objects
for each row
execute function data.objects_after_insert();

-- Initial data

drop role if exists http;
create role http login password 'http';
grant usage on schema api to http;
grant execute on all functions in schema api to http;

select data.init();

select pallas_project.init();

analyze;
