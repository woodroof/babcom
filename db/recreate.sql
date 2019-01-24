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

-- drop schema error;

create schema error;

-- drop schema json;

create schema json;

-- drop schema json_test;

create schema json_test;

-- drop schema pallas_project;

create schema pallas_project;

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
  v_message text;
  v_client_id integer;
  v_client_code text;
begin
  assert in_notification_code is not null;

  delete from data.notifications
  where code = in_notification_code
  returning message, client_id
  into v_message, v_client_id;

  if v_client_id is null then
    raise exception 'Can''t find notification with code "%"', in_notification_code;
  end if;

  select code
  into v_client_code
  from data.clients
  where id = v_client_id;

  assert v_client_code is not null;

  return jsonb_build_object(
    'client_code',
    v_client_code,
    'message',
    v_message);
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
begin
  assert in_client_id is not null;
  assert in_type is not null;

  insert into data.notifications(message, client_id)
  values(v_message, in_client_id)
  returning code into v_notification_code;

  perform pg_notify('api_channel', v_notification_code);
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
  v_login_id integer;
  v_actor_function record;
  v_actor record;
  v_title text;
  v_subtitle text;
  v_actors jsonb[];
begin
  assert in_request_id is not null;

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

  for v_actor_function in
    select actor_id, json.get_string_opt(data.get_attribute_value(actor_id, 'actor_function'), null) as actor_function
    from data.login_actors
    where login_id = v_login_id
    for share
  loop
    if v_actor_function is not null then
      execute format('select %s($1)', v_actor_function.actor_function)
      using v_actor_function.actor_id;
    end if;
  end loop;

  for v_actor in
    select
      o.code as id,
      json.get_string_opt(data.get_attribute_value(actor_id, 'title', actor_id), null) as title,
      json.get_string_opt(data.get_attribute_value(actor_id, 'subtitle', actor_id), null) as subtitle
    from data.login_actors la
    join data.objects o
      on o.id = la.actor_id
    where la.login_id = v_login_id
    order by title
  loop
    v_actors :=
      array_append(
        v_actors,
        (
          jsonb_build_object('id', v_actor.id) ||
          case when v_actor.title is not null then jsonb_build_object('title', v_actor.title) else jsonb '{}' end ||
          case when v_actor.subtitle is not null then jsonb_build_object('subtitle', v_actor.subtitle) else jsonb '{}' end
        ));
  end loop;

  assert v_actors is not null;

  perform api_utils.create_notification(in_client_id, in_request_id, 'actors', jsonb_build_object('actors', to_jsonb(v_actors)));
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
  for update;

  if v_actor_id is null then
    raise exception 'Client % has no active actor', in_client_id;
  end if;

  perform 1
  from data.objects
  where id = v_object_id
  for update;

  v_list := data.get_next_list(in_client_id, v_object_id);

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
  for update;

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
  v_object_id integer;
  v_list_object_id integer;
  v_content text[];
  v_is_visible boolean;
  v_actor_id integer;
  v_list_element_function text;
begin
  assert in_client_id is not null;

  select actor_id
  into v_actor_id
  from data.clients
  where id = in_client_id
  for update;

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
    raise exception 'Attempt to open list object in non-existing object %', v_object_code;
  end if;

  select id
  into v_list_object_id
  from data.objects
  where
    code = v_list_object_code and
    type = 'instance';

  if v_object_id is null then
    raise exception 'Attempt to open non-existing list object %', v_list_object_code;
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
  v_object_id integer;
  v_actor_id integer;
  v_visited_object_ids integer[];
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
  for update;

  if v_actor_id is null then
    raise exception 'Client % has no active actor', in_client_id;
  end if;

  select id
  into v_object_id
  from data.objects
  where
    code = v_object_code and
    type = 'instance'
  for update;

  if v_object_id is null then
    perform data.log('error', format('Attempt to subscribe for non-existing object'' changes with code %s. Redirecting to 404.', v_object_code));

    v_object_id := data.get_integer_param('not_found_object_id');

    select true
    into v_object_exists
    from data.objects
    where
      id = v_object_id and
      type = 'instance'
    for update;

    if v_object_exists is null then
      raise exception 'Object % not found', v_object_id;
    end if;
  end if;

  loop
    if v_visited_object_ids is not null and array_position(v_visited_object_ids, v_object_id) is not null then
      raise exception 'Redirection cycle detected for object %', v_object_id;
    end if;

    v_visited_object_ids := array_append(v_visited_object_ids, v_object_id);

    -- Вызываем функцию на получение полной карточки объекта, если есть
    v_full_card_function := json.get_string_opt(data.get_attribute_value(v_object_id, 'full_card_function'), null);

    if v_full_card_function is not null then
      execute format('select %s($1, $2)', v_full_card_function)
      using v_object_id, v_actor_id;
    end if;

    -- Смотрим на наличие redirect'а
    v_redirect_object_id := json.get_integer_opt(data.get_attribute_value(v_object_id, 'redirect', v_actor_id), null);
    if v_redirect_object_id is not null then
      v_object_id := v_redirect_object_id;

      -- Проверяем наличие объекта
      select true
      into v_object_exists
      from data.objects
      where
       id = v_object_id and
       type = 'instance'
      for update;

      if v_object_exists is null then
        raise exception 'Object % not found', v_object_id;
      end if;

      continue;
    end if;

    -- Проверяем видимость
    v_is_visible := json.get_boolean_opt(data.get_attribute_value(v_object_id, 'is_visible', v_actor_id), false);
    if not v_is_visible then
      v_object_id := data.get_integer_param('not_found_object_id');
      continue;
    end if;

    exit;
  end loop;

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
  if v_object->'attributes' ? 'content' then
    v_list := data.get_next_list(in_client_id, v_object_id);
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
  v_object_id integer;
  v_actor_id integer;
  v_touch_function text;
begin
  assert in_client_id is not null;

  select actor_id
  into v_actor_id
  from data.clients
  where id = in_client_id
  for update;

  if v_actor_id is null then
    raise exception 'Client % has no active actor', in_client_id;
  end if;

  select id
  into v_object_id
  from data.objects
  where code = v_object_code
  for update;

  if v_object_id is null then
    raise exception 'Attempt to touch non-existing object %', v_object_code;
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
  for update;

  if v_actor_id is null then
    raise exception 'Client % has no active actor', in_client_id;
  end if;

  perform 1
  from data.objects
  where id = v_object_id
  for update;

  select id
  into v_subscription_id
  from data.client_subscriptions
  where
    object_id = v_object_id and
    client_id = in_client_id;

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

-- drop function data.add_object_to_object(integer, integer);

create or replace function data.add_object_to_object(in_object_id integer, in_parent_object_id integer)
returns void
volatile
as
$$
declare
  v_exists boolean;
  v_cycle boolean;
  v_row record;
begin
  assert data.is_instance(in_object_id);
  assert data.is_instance(in_parent_object_id);

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
        oo.parent_object_id != oo.object_id and
        oo.intermediate_object_ids is null
    )
  for share;

  insert into data.object_objects(parent_object_id, object_id, intermediate_object_ids)
  select
    oo2.parent_object_id,
    oo1.object_id,
    oo1.intermediate_object_ids || in_object_id || in_parent_object_id || oo2.intermediate_object_ids
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
    in_parent_object_id || oo.intermediate_object_ids
  from data.object_objects oo
  where
    oo.object_id = in_parent_object_id and
    oo.object_id != oo.parent_object_id
  union
  select
    in_parent_object_id,
    oo.object_id,
    oo.intermediate_object_ids || in_object_id
  from data.object_objects oo
  where
    oo.parent_object_id = in_object_id and
    oo.object_id != oo.parent_object_id
  union
  select in_parent_object_id, in_object_id, null;
end;
$$
language plpgsql;

-- drop function data.attribute_change2jsonb(integer, integer, jsonb);

create or replace function data.attribute_change2jsonb(in_attribute_id integer, in_value_object_id integer, in_value jsonb)
returns jsonb
volatile
as
$$
declare
  v_result jsonb;
begin
  assert in_attribute_id is not null;

  v_result := jsonb_build_object('id', in_attribute_id);
  if in_value_object_id is not null then 
    v_result := v_result || jsonb_build_object('value_object_id', in_value_object_id);
  end if;
  if in_value is not null then
    v_result := v_result || jsonb_build_object('value', in_value);
  end if;
  return v_result;
end;
$$
language plpgsql;

-- drop function data.attribute_change2jsonb(text, integer, jsonb);

create or replace function data.attribute_change2jsonb(in_attribute_code text, in_value_object_id integer, in_value jsonb)
returns jsonb
volatile
as
$$
begin
  return data.attribute_change2jsonb(data.get_attribute_id(in_attribute_code), in_value_object_id, in_value);
end;
$$
language plpgsql;

-- drop function data.calc_content_diff(jsonb, jsonb);

create or replace function data.calc_content_diff(in_original_content jsonb, in_new_content jsonb)
returns jsonb
volatile
as
$$
-- add - массив объектов с полями position и object_code, position может отсутствовать
-- remove - массив кодов объектов
declare
  v_add jsonb := jsonb '[]';
  v_remove jsonb := jsonb '[]';
  v_code text;
begin
  perform json.get_string_array_opt(in_original_content, null);
  perform json.get_string_array_opt(in_new_content, null);

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
      select json.get_string(value)
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
      v_current_original_value text;
      v_current_new_value text;
      v_original_test_idx integer;
      v_new_test_idx integer;
      v_remove_indexes integer[];
      v_modified_content jsonb := in_original_content;
    begin
      -- Сначала определим, что нужно удалить
      while v_original_idx != v_original_size and v_new_idx != v_new_size loop
        v_current_original_value := json.get_string(in_original_content->v_original_idx);
        v_current_new_value := json.get_string(in_new_content->v_new_idx);

        if v_current_original_value = v_current_new_value then
          v_original_idx := v_original_idx + 1;
          v_new_idx := v_new_idx + 1;
        else
          v_original_test_idx :=
            json.array_find(in_original_content, to_jsonb(v_current_new_value), v_original_idx + 1);
          v_new_test_idx :=
            json.array_find(in_new_content, to_jsonb(v_current_original_value), v_new_idx + 1);

          -- Определяем, что эффективнее - удалять объекты из оригинального массива или добавлять в результирующий
          if v_original_test_idx is not null and v_new_test_idx is not null then
            if v_original_test_idx - v_original_idx <= v_new_test_idx - v_new_idx then
              -- Удаляем
              while v_original_idx != v_original_test_idx loop
                v_remove_indexes := array_prepend(v_original_idx, v_remove_indexes);
                v_remove := v_remove || in_original_content->v_original_idx;
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
            v_remove := v_remove || in_original_content->v_original_idx;
            v_original_idx := v_original_idx + 1;
          end if;
        end if;
      end loop;

      while v_original_idx != v_original_size loop
        v_remove_indexes := array_prepend(v_original_idx, v_remove_indexes);
        v_remove := v_remove || in_original_content->v_original_idx;
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

      if v_original_size > 0 then
        v_original_idx := 0;

        while v_original_idx != v_original_size loop
          assert v_new_idx != v_new_size;

          v_current_original_value := json.get_string(v_modified_content->v_original_idx);
          v_current_new_value := json.get_string(in_new_content->v_new_idx);

          if v_current_original_value = v_current_new_value then
            v_original_idx := v_original_idx + 1;
            v_new_idx := v_new_idx + 1;
          else
            v_add :=
              v_add ||
              jsonb_build_object('position', v_current_original_value, 'object_code', v_current_new_value);
            v_new_idx := v_new_idx + 1;
          end if;
        end loop;
      end if;

      while v_new_idx != v_new_size loop
        v_add :=
          v_add ||
          jsonb_build_object('object_code', json.get_string(in_new_content->v_new_idx));
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

-- drop function data.change_current_object(integer, text, integer, jsonb);

create or replace function data.change_current_object(in_client_id integer, in_request_id text, in_object_id integer, in_changes jsonb)
returns boolean
volatile
as
$$
-- Функция возвращает, отправляли ли сообщение клиенту in_client_id
-- Если функция вернула false, то скорее всего внешнему коду нужно сгенерировать событие ok или action
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_subscription_exists boolean;
  v_diffs jsonb;
  v_diff record;
  v_message_sent boolean := false;
  v_request_id text;
  v_notification_data jsonb;
begin
  assert in_client_id is not null;
  assert in_request_id is not null;
  assert in_changes is not null;

  select true
  into v_subscription_exists
  from data.client_subscriptions
  where
    client_id = in_client_id and
    object_id = in_object_id;

  -- Если стреляет этот ассерт, то нам нужно вызывать другую функцию
  assert v_subscription_exists;

  v_diffs := data.change_object(in_object_id, in_changes, v_actor_id);

  for v_diff in
  (
    select
      json.get_string(value, 'object_id') as object_id,
      json.get_integer(value, 'client_id') as client_id,
      (case when value ? 'object' then value->'object' else null end) as object,
      (case when value ? 'list_changes' then value->'list_changes' else null end) as list_changes
    from jsonb_array_elements(v_diffs)
  )
  loop
    assert v_diff.object is not null or v_diff.list_changes is not null;

    if v_diff.client_id = in_client_id then
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

-- drop function data.change_object(integer, jsonb, integer);

create or replace function data.change_object(in_object_id integer, in_changes jsonb, in_actor_id integer default null::integer)
returns jsonb
volatile
as
$$
-- В параметре in_changes приходит массив объектов с полями id, value_object_id, value
-- Если присутствует, value_object_id меняет именно значение, задаваемое для указанного объекта
-- Если value отсутствует (именно отсутствует, а не равно jsonb 'null'!), то указанное значение удаляется, в противном случае - устанавливается

-- Возвращается массив объектов с полями client_id, object и list_changes, поля object и list_changes могут отсутствовать
declare
  v_changes jsonb := data.filter_changes(in_object_id, in_changes);
  v_object_code text;
  v_default_template jsonb;

  v_subscriptions jsonb := jsonb '[]';
  v_subscription_objects jsonb := jsonb '[]';

  v_list_changed boolean := false;

  v_ret_val jsonb := jsonb '[]';
begin
  assert in_actor_id is null or data.is_instance(in_actor_id);

  if v_changes = jsonb '[]' then
    return jsonb '[]';
  end if;

  v_object_code := data.get_object_code(in_object_id);
  v_default_template := data.get_param('template');

  perform *
  from data.objects
  where id = in_object_id
  for update;

  -- Сохраним атрибуты и действия для всех клиентов, подписанных на получение изменений данного объекта
  declare
    v_subscription record;
    v_actor_id integer;
  begin
    for v_subscription in
    (
      select
        id,
        client_id
      from data.client_subscriptions
      where object_id = in_object_id
    )
    loop
      v_actor_id := data.get_active_actor_id(v_subscription.client_id);

      -- Невидимые объекты должны были пройти через change_object, подписки были бы удалены
      assert json.get_boolean(data.get_attribute_value(in_object_id, 'is_visible', v_actor_id));

      v_subscriptions :=
        v_subscriptions ||
        jsonb_build_object(
          'id',
          v_subscription.id,
          'client_id',
          v_subscription.client_id,
          'actor_id',
          v_actor_id,
          'data',
          data.get_object(in_object_id, v_actor_id, 'full', in_object_id));
    end loop;
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

  -- Меняем состояние объекта
  declare
    v_change record;
    v_content_attribute_id integer := data.get_attribute_id('content');
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
      if v_change.attribute_id = v_content_attribute_id then
        v_list_changed := true;
      end if;

      if v_change.value is null then
        perform data.delete_attribute_value(
          in_object_id,
          v_change.attribute_id,
          v_change.value_object_id,
          in_actor_id);
      else
        perform data.set_attribute_value(
          in_object_id,
          v_change.attribute_id,
          v_change.value,
          v_change.value_object_id,
          in_actor_id);
      end if;
    end loop;
  end;

  -- Берём новые атрибуты и действия для тех же клиентов
  if v_subscriptions != jsonb '[]' then
    declare
      v_subscription record;
      v_full_card_function text := json.get_string_opt(data.get_attribute_value(in_object_id, 'full_card_function'), null);
      v_new_data jsonb;
      v_object jsonb;
      v_list_changes jsonb;
      v_attributes jsonb;
      v_actions jsonb;
      v_object_template jsonb;
      v_ret_val_element jsonb;
    begin
      for v_subscription in
      (
        select
          json.get_integer(value, 'id') as id,
          json.get_integer(value, 'client_id') as client_id,
          json.get_integer(value, 'actor_id') as actor_id,
          json.get_object(value, 'data') as data
        from jsonb_array_elements(v_subscriptions)
      )
      loop
        if v_full_card_function is not null then
          execute format('select %s($1, $2)', v_full_card_function)
          using in_object_id, v_subscription.actor_id;
        end if;

        -- Объект стал невидимым - отправляем специальный diff и вычищаем подписки
        if not json.get_boolean_opt(data.get_attribute_value(in_object_id, 'is_visible', v_subscription.actor_id), false) then
          v_ret_val :=
            v_ret_val ||
            jsonb_build_object(
              'object_id',
              v_object_code,
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

        v_new_data := data.get_object(in_object_id, v_subscription.actor_id, 'full', in_object_id);

        v_object := null;
        v_list_changes := jsonb '{}';

        -- Сравниваем и при нахождении различий включаем в diff
        if v_new_data != v_subscription.data then
          v_object := v_new_data;
        end if;

        if v_list_changed then
          declare
            v_content_diff jsonb;
            v_add jsonb;
            v_remove jsonb;
            v_remove_list_changes jsonb;
            v_add_list_changes jsonb := jsonb '[]';
          begin
            v_content_diff :=
              data.calc_content_diff(
                json.get_array_opt(json.get_object_opt(json.get_object(v_subscription.data, 'attributes'), 'content', jsonb '{}'), 'value', null),
                json.get_array_opt(json.get_object_opt(json.get_object(v_new_data, 'attributes'), 'content', jsonb '{}'), 'value', null));

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

                v_list_changes := v_list_changes || jsonb_build_object('remove', v_remove_list_changes);

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
                          data.get_object(v_object_id, v_subscription.actor_id, 'mini', in_object_id));
                      if v_position is not null then
                        v_add_list_change := v_add_list_change || jsonb_build_object('position', v_position);
                      end if;
                      v_add_list_changes := v_add_list_changes || v_add_list_change;
                    end if;
                  end loop;
                end;
              end if;

              if v_add_list_changes != jsonb '[]' then
                v_list_changes := v_list_changes || jsonb_build_object('add', v_add_list_changes);
              end if;
            end if;
          end;
        end if;

        if v_object is not null or v_list_changes != jsonb '{}' then
          v_ret_val_element := jsonb_build_object('object_id', v_object_code, 'client_id', v_subscription.client_id);

          if v_object is not null then
            v_ret_val_element := v_ret_val_element || jsonb_build_object('object', v_object);
          end if;

          if v_list_changes!= jsonb '{}' then
            v_ret_val_element := v_ret_val_element || jsonb_build_object('list_changes', v_list_changes);
          end if;

          v_ret_val := v_ret_val || v_ret_val_element;
        end if;
      end loop;
    end;
  end if;

  -- Берём новые миникарточки для тех же списков
  if v_subscription_objects != jsonb '[]' then
    declare
      v_mini_card_function text := json.get_string_opt(data.get_attribute_value(in_object_id, 'mini_card_function'), null);
      v_list record;
      v_new_data jsonb;
      v_attributes jsonb;
      v_actions jsonb;
      v_set_visible integer[];
      v_set_invisible integer[];
      v_object_template jsonb;
      v_object jsonb;
      v_position_object_id integer;
      v_add jsonb;
      v_object_code text;
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
            v_object = v_new_data;
            v_object_code := data.get_object_code(v_list.object_id);

            if not v_list.is_visible then
              v_set_visible := array_append(v_set_visible, v_list.id);

              v_add := jsonb_build_object('object', v_object);

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
                  v_object_code,
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
                  v_object_code,
                  'client_id',
                  v_list.client_id,
                  'list_changes',
                  jsonb_build_object('change', jsonb_build_array(v_object)));
            end if;
          end if;
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

-- drop function data.change_object_and_notify(integer, jsonb, integer);

create or replace function data.change_object_and_notify(in_object_id integer, in_changes jsonb, in_actor_id integer default null::integer)
returns void
volatile
as
$$
declare
  v_diffs jsonb := data.change_object(in_object_id, in_changes, in_actor_id);
  v_diff record;
  v_notification_data jsonb;
begin
  for v_diff in
  (
    select
      json.get_string(value, 'object_id') as object_id,
      json.get_integer(value, 'client_id') as client_id,
      (case when value ? 'object' then value->'object' else null end) as object,
      (case when value ? 'list_changes' then value->'list_changes' else null end) as list_changes
    from jsonb_array_elements(v_diffs)
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

-- drop function data.delete_attribute_value(integer, integer, integer, integer, text);

create or replace function data.delete_attribute_value(in_object_id integer, in_attribute_id integer, in_value_object_id integer, in_actor_id integer, in_reason text default null::text)
returns void
volatile
as
$$
-- Как правило вместо этой функции следует вызывать data.change_object
declare
  v_attribute_value_id integer;
begin
  assert data.is_instance(in_object_id);
  assert in_attribute_id is not null;

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
  v_value jsonb;
  v_next_change jsonb;
begin
  assert data.is_instance(in_object_id);
  perform json.get_object_array(in_changes);

  for v_change in
  (
    select
      json.get_integer(value, 'id') as id,
      json.get_integer_opt(value, 'value_object_id', null) as value_object_id,
      value->'value' as value
    from jsonb_array_elements(in_changes)
  )
  loop
    v_value := data.get_raw_attribute_value(in_object_id, v_change.id, v_change.value_object_id);

    if
      -- Удалять нечего
      v_change.value is null and v_value is null or
      -- Уже то же значение
      v_change.value = v_value
    then
      continue;
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

  return jsonb_build_object('groups', to_jsonb(v_filtered_groups));
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
    select class_id
    into v_class_id
    from data.objects
    where id = in_object_id;

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
  assert data.is_instance(in_actor_id);
  assert data.can_attribute_be_overridden(in_attribute_id);

  select av.value
  into v_attribute_value
  from data.attribute_values av
  left join data.object_objects oo on
    av.value_object_id = oo.parent_object_id and
    oo.object_id = in_actor_id
  left join data.attribute_values pr on
    pr.object_id = av.value_object_id and
    pr.attribute_id = v_priority_attribute_id and
    pr.value_object_id is null
  where
    av.object_id = in_object_id and
    av.attribute_id = in_attribute_id and
    (
      av.value_object_id is null or
      oo.id is not null
    )
  order by json.get_integer_opt(pr.value, 0) desc
  limit 1;

  if v_attribute_value is null then
    select class_id
    into v_class_id
    from data.objects
    where id = in_object_id;

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

-- drop function data.get_attribute_value_modification_date(integer, integer, integer);

create or replace function data.get_attribute_value_modification_date(in_object_id integer, in_attribute_id integer, in_value_object_id integer)
returns timestamp with time zone
stable
as
$$
declare
  v_date timestamp with time zone;
begin
  -- Странно пользоваться этой функцией, если мы работаем с атрибутами классов
  assert data.is_instance(in_object_id);
  perform data.get_attribute_code(in_attribute_id);

  if in_value_object_id is null then
    select start_time
    into v_date
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id is null;
  else
    select start_time
    into v_date
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id = in_value_object_id;
  end if;

  return v_date;
end;
$$
language plpgsql;

-- drop function data.get_attribute_value_modification_date(integer, text, integer);

create or replace function data.get_attribute_value_modification_date(in_object_id integer, in_attribute_code text, in_value_object_id integer)
returns timestamp with time zone
stable
as
$$
begin
  return data.get_attribute_value_modification_date(in_object_id, data.get_attribute_id(in_attribute_code), in_value_object_id);
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
  v_page_size integer := data.get_integer_param('page_size');
  v_object_code text := data.get_object_code(in_object_id);
  v_actor_id integer;
  v_last_object_id integer;
  v_content text[];
  v_content_length integer;
  v_client_subscription_id integer;
  v_object record;
  v_mini_card_function text;
  v_is_visible boolean;
  v_count integer := 0;
  v_has_more boolean := false;
  v_objects jsonb[] := array[]::jsonb[];
begin
  assert v_page_size > 0;

  select actor_id
  into v_actor_id
  from data.clients
  where id = in_client_id
  for update;

  assert v_actor_id is not null;

  v_content = json.get_string_array(data.get_attribute_value(in_object_id, 'content', v_actor_id));
  assert array_utils.is_unique(v_content);
  assert array_position(v_content, v_object_code) is null;

  v_content_length := array_length(v_content, 1);

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
stable
as
$$
declare
  v_object_data jsonb := data.get_object_data(in_object_id, in_actor_id, in_card_type, in_actions_object_id);
  v_attributes jsonb := json.get_object(v_object_data, 'attributes');
  v_actions jsonb := json.get_object_opt(v_object_data, 'actions', null);
  v_template jsonb := json.get_object_opt(data.get_attribute_value(in_object_id, 'template', in_actor_id), null);
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
stable
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
          when lag(av.attribute_id) over (partition by av.attribute_id order by av.priority desc, json.get_integer_opt(pr.value, 0) desc) is null
          then true
          else false
        end as needed
      from
      (
        select attribute_id, value, value_object_id, 1 as priority
        from data.attribute_values
        where object_id = in_object_id
        union all
        select attribute_id, value, null, 0
        from data.attribute_values
        where
          object_id in (
            select class_id
            from data.objects
            where id = in_object_id
          )
      ) av
      left join data.object_objects oo on
        av.value_object_id = oo.parent_object_id and
        oo.object_id = in_actor_id
      left join data.attribute_values pr on
        pr.object_id = av.value_object_id and
        pr.attribute_id = v_priority_attribute_id and
        pr.value_object_id is null
      where
        av.value_object_id is null or
        oo.id is not null
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
      execute format('select %s($1, $2, $3)', v_attribute.value_description_function)
      using v_attribute.id, v_attribute.value, in_actor_id
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
    select true
    into v_object_exists
    from data.objects
    where id = in_object_id;

    assert v_object_exists;
    perform data.get_attribute_code(in_attribute_id);

    select value
    into v_attribute_value
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id is null;
  else
    assert data.is_instance(in_object_id);
    assert data.can_attribute_be_overridden(in_attribute_id);

    select value
    into v_attribute_value
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id = in_value_object_id;
  end if;

  return v_attribute_value;
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
  ('content', null, 'Массив идентификаторов объектов списка, integer[]', 'hidden', 'full', null, true),
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
  ('subtitle', null, 'Подзаголовок, string', 'normal', null, null, true),
  ('template', null, 'Шаблон объекта, object', 'system', null, null, true),
  ('temporary_object', null, 'Атрибут, наличие которого говорит о том, что открытый объект не нужно сохранять в истории', 'hidden', 'full', null, false),
  ('title', null, 'Заголовок, string', 'normal', null, null, true),
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
  ('type', null, 'Тип объекта, string', 'hidden', null, null, true);

  insert into data.params(code, value, description) values
  ('page_size', jsonb '10', 'Количество элементов списка, получаемых за один раз'),
  ('template', jsonb '{"groups": []}', 'Шаблон по умолчанию');
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
  values(in_severity, in_message, in_actor_id);
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

-- drop function data.remove_object_from_object(integer, integer);

create or replace function data.remove_object_from_object(in_object_id integer, in_parent_object_id integer)
returns void
volatile
as
$$
declare
  v_connection_id integer;
  v_ids integer[];
begin
  assert data.is_instance(in_object_id);
  assert data.is_instance(in_parent_object_id);

  if in_object_id = in_parent_object_id then
    raise exception 'Attempt to remove object % from itself', in_object_id;
  end if;

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

  insert into data.object_objects_journal(parent_object_id, object_id, intermediate_object_ids, start_time, end_time)
  select parent_object_id, object_id, intermediate_object_ids, start_time, clock_timestamp()
  from data.object_objects
  where id = any(v_ids);

  delete from data.object_objects
  where id = any(v_ids);
end;
$$
language plpgsql;

-- drop function data.set_attribute_value(integer, integer, jsonb, integer, integer, text);

create or replace function data.set_attribute_value(in_object_id integer, in_attribute_id integer, in_value jsonb, in_value_object_id integer, in_actor_id integer, in_reason text default null::text)
returns void
volatile
as
$$
-- Как правило вместо этой функции следует вызывать data.change_object
declare
  v_attribute_value record;
  v_end_time timestamp with time zone;
begin
  assert data.is_instance(in_object_id);
  assert in_attribute_id is not null;
  assert in_value is not null;

  if in_value_object_id is null then
    select id, object_id, attribute_id, value_object_id, value, start_time, start_reason, start_actor_id
    into v_attribute_value
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id is null;
  else
    assert data.can_attribute_be_overridden(in_attribute_id);

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

-- drop function data.should_attribute_value_be_changed(integer, integer, integer, integer, integer);

create or replace function data.should_attribute_value_be_changed(in_object_id integer, in_source_attribute_id integer, in_source_value_object_id integer, in_destination_attribute_id integer, in_destination_value_object_id integer)
returns boolean
stable
as
$$
declare
  v_source_attribute_modification_date timestamp with time zone :=
    data.get_attribute_value_modification_date(in_object_id, in_source_attribute_id, in_source_value_object_id);
  v_destination_attribute_modification_date timestamp with time zone :=
    data.get_attribute_value_modification_date(in_object_id, in_destination_attribute_id, in_destination_value_object_id);
begin
  return
    v_destination_attribute_modification_date is null and v_source_attribute_modification_date is not null or
    v_source_attribute_modification_date is null and v_destination_attribute_modification_date is not null or
    v_source_attribute_modification_date > v_destination_attribute_modification_date;
end;
$$
language plpgsql;

-- drop function data.should_attribute_value_be_changed(integer, text, integer, text, integer);

create or replace function data.should_attribute_value_be_changed(in_object_id integer, in_source_attribute_code text, in_source_value_object_id integer, in_destination_attribute_code text, in_destination_value_object_id integer)
returns boolean
stable
as
$$
begin
  return data.should_attribute_value_be_changed(
    in_object_id,
    data.get_attribute_id(in_source_attribute_code),
    in_source_value_object_id,
    data.get_attribute_id(in_destination_attribute_code),
    in_destination_value_object_id);
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

-- drop function pallas_project.act_create_debatle_step1(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_create_debatle_step1(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_title text := json.get_string(in_user_params, 'title');
  v_debatle_code text;
  v_debatle_id  integer;
  v_debatle_class_id integer := data.get_class_id('debatle');
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_debatle_theme_attribute_id integer := data.get_attribute_id('system_debatle_theme');
  v_debatle_status_attribute_id integer := data.get_attribute_id('debatle_status');
  v_system_debatle_person1_attribute_id integer := data.get_attribute_id('system_debatle_person1');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');

  v_debatles_all_id integer := data.get_object_id('debatles_all');
  v_debatles_my_id integer := data.get_object_id('debatles_my');
  v_debatles_draft_id integer := data.get_object_id('debatles_draft');
  v_master_group_id integer := data.get_object_id('master');

  v_content text[];
  v_new_content text[];

  v_temp_object_code text;
  v_temp_object_id integer;
begin
  assert in_request_id is not null;
  -- создаём новый дебатл
  insert into data.objects(class_id) values (v_debatle_class_id) returning id, code into v_debatle_id, v_debatle_code;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatle_id, v_debatle_theme_attribute_id, to_jsonb(v_title), null),
  (v_debatle_id, v_debatle_status_attribute_id, jsonb '"draft"', null),
  (v_debatle_id, v_is_visible_attribute_id, jsonb 'true', v_actor_id),
  (v_debatle_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (v_debatle_id, v_system_debatle_person1_attribute_id, to_jsonb(v_actor_id), null);

  -- Добавляем его в список всех и в список моих для того, кто создаёт
  -- Блокируем списки
  perform * from data.objects where id = v_debatles_all_id for update;
  perform * from data.objects where id = v_debatles_my_id for update;
  perform * from data.objects where id = v_debatles_draft_id for update;

  -- Достаём, меняем, кладём назад
  v_content := array[]::text[];
  v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_all_id, 'content', v_master_group_id), v_content);
  v_new_content := array_append(v_content, v_debatle_code);
  if v_new_content <> v_content then
    perform data.change_object_and_notify(v_debatles_all_id, 
                                          jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_master_group_id, to_jsonb(v_new_content))),
                                          v_actor_id);
  end if;
  v_content := array[]::text[];
  v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_my_id,'content', v_actor_id), v_content);
  v_new_content := array_append(v_content, v_debatle_code);
  if v_new_content <> v_content then
    perform data.change_object_and_notify(v_debatles_my_id, 
                                         jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_actor_id, to_jsonb(v_new_content))),
                                         v_actor_id);
  end if;
  v_content := array[]::text[];
  v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_draft_id,'content', v_actor_id), v_content);
  v_new_content := array_append(v_content, v_debatle_code);
  if v_new_content <> v_content then
    perform data.change_object_and_notify(v_debatles_draft_id, 
                                          jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_actor_id, to_jsonb(v_new_content))),
                                          v_actor_id);
  end if;

  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'action',
    format('{"action": "open_object", "action_data": {"object_id": "%s"}}', v_debatle_code)::jsonb);
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
  v_priority_attribute_id integer := data.get_attribute_id('priority');

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
  (v_person_id, v_title_attribute_id, to_jsonb(v_title)),
  (v_person_id, v_priority_attribute_id, jsonb '200');

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
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_debatle_status text;
  v_system_debatle_person1 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person1'), -1);
  v_system_debatle_person2 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person2'), -1);
  v_system_debatle_judje integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_judge'), -1);
  v_debatle_title text := json.get_string_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_theme'), '');

  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_debatle_temp_person_list_edited_person_attribute_id integer := data.get_attribute_id('debatle_temp_person_list_edited_person');
  v_system_debatle_temp_person_list_debatle_id_attribute_id integer := data.get_attribute_id('system_debatle_temp_person_list_debatle_id');

  v_debatle_temp_person_list_class_id integer := data.get_class_id('debatle_temp_person_list');
  v_content text[];

  v_temp_object_code text;
  v_temp_object_id integer;
begin
  assert in_request_id is not null;

  if v_edited_person not in ('instigator', 'opponent', 'judge') then
    perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      format('{"action": "show_message", "action_data": {"title": "%s", "message": "%s"}}', 'Ошибка', 'Непонятно, какую из персон менять. Наверное что-то пошло не так. Обратитесь к мастеру.')::jsonb); 
    return;
  end if;

  -- создаём темповый список персон
  insert into data.objects(class_id) values (v_debatle_temp_person_list_class_id) returning id, code into v_temp_object_id, v_temp_object_code;

  select array_agg(o.code) into v_content
  from data.object_objects oo
    left join data.objects o on o.id = oo.object_id 
  where oo.parent_object_id = data.get_object_id('player')
    and oo.object_id not in (oo.parent_object_id, v_system_debatle_person1, v_system_debatle_person2, v_system_debatle_judje);

  if v_content is null then
   perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      format('{"action": "show_message", "action_data": {"title": "%s", "message": "%s"}}', 'Ошибка', 'Нет подходящих персон для изменения дебатла')::jsonb); 
    return;
  end if;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_temp_object_id, v_title_attribute_id, to_jsonb(format('Изменение дебатла "%s"', v_debatle_title)), v_actor_id),
  (v_temp_object_id, v_is_visible_attribute_id, jsonb 'true', v_actor_id),
  (v_temp_object_id, v_debatle_temp_person_list_edited_person_attribute_id, to_jsonb(v_edited_person), null),
  (v_temp_object_id, v_content_attribute_id, to_jsonb(v_content), null),
  (v_temp_object_id, v_system_debatle_temp_person_list_debatle_id_attribute_id, to_jsonb(v_debatle_id), null);

  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'action',
    format('{"action": "open_object", "action_data": {"object_id": "%s"}}', v_temp_object_code)::jsonb);
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

  v_is_master boolean := pallas_project.is_in_group(v_actor_id, 'master');
  v_master_group_id integer:= data.get_object_id('master'); 

  v_debatle_status text;
  v_system_debatle_person1 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person1'), -1);
  v_system_debatle_person2 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person2'), -1);
  v_system_debatle_judge integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_judge'), -1);

  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');

  v_content text[];
  v_new_content text[];
  v_debatles_draft_id integer := data.get_object_id('debatles_draft');
  v_debatles_new_id integer := data.get_object_id('debatles_new');
  v_debatles_future_id integer := data.get_object_id('debatles_future');
  v_debatles_current_id integer := data.get_object_id('debatles_current');
  v_debatles_closed_id integer := data.get_object_id('debatles_closed');
  v_debatles_deleted_id integer := data.get_object_id('debatles_deleted');

  v_changes jsonb[];
  v_message_sent boolean;
begin
  assert in_request_id is not null;

  v_debatle_status := json.get_string_opt(data.get_attribute_value(v_debatle_id, 'debatle_status'), '~~~');

  if v_new_status = 'new' and v_debatle_status = 'draft' and (v_is_master or v_actor_id = v_system_debatle_person1) then
    -- удаляем из черновиков у автора, добавляем в неподтверждённые мастерам
    perform * from data.objects where id = v_debatles_draft_id for update;
    perform * from data.objects where id = v_debatles_new_id for update;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_draft_id, 'content', v_system_debatle_person1), array[]::text[]);
    v_new_content := array_remove(v_content, v_debatle_code);
    if v_content <> v_new_content then
       perform data.change_object_and_notify(v_debatles_draft_id, 
                                            jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_system_debatle_person1, to_jsonb(v_new_content))),
                                            v_actor_id);
    end if;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_new_id, 'content', v_master_group_id), array[]::text[]);
    v_new_content := array_append(v_content, v_debatle_code);
    if v_content <> v_new_content then
     perform data.change_object_and_notify(v_debatles_new_id, 
                                          jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_master_group_id, to_jsonb(v_new_content))),
                                          v_actor_id);
    end if;

  elsif v_new_status = 'future' and v_debatle_status = 'new' and v_is_master then
    -- удаляем из неподтверждённых у мастера, добавляем в будущие мастеру
    perform * from data.objects where id = v_debatles_new_id for update;
    perform * from data.objects where id = v_debatles_future_id for update;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_new_id, 'content', v_master_group_id), array[]::text[]);
    v_new_content := array_remove(v_content, v_debatle_code);
    if v_content <> v_new_content then
       perform data.change_object_and_notify(v_debatles_new_id, 
                                            jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_master_group_id, to_jsonb(v_new_content))),
                                            v_actor_id);
    end if;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_future_id, 'content', v_master_group_id), array[]::text[]);
    v_new_content := array_append(v_content, v_debatle_code);
    if v_content <> v_new_content then
     perform data.change_object_and_notify(v_debatles_future_id, 
                                           jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_master_group_id, to_jsonb(v_new_content))),
                                           v_actor_id);
    end if;
     -- TODO тут следовало бы разослать всем причастным весть о грядущем дебатле!!!!!!!!!!!!!!!

  elsif v_new_status = 'vote' and v_debatle_status = 'future' and (v_is_master or v_system_debatle_judge = v_actor_id) then
    if v_system_debatle_judge = -1 or v_system_debatle_person1 =-1 or v_system_debatle_person2 =-1 then
      perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Попросите мастера внести недостающих участников дебатла прежде чем начать');
      return;
    end if;
  -- удаляем из будущих у мастера, добавляем в текущие всем (TODO вообще не совсем всем, а только тем, кто в аудиории дебатла)
    perform * from data.objects where id = v_debatles_future_id for update;
    perform * from data.objects where id = v_debatles_current_id for update;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_future_id, 'content', v_master_group_id), array[]::text[]);
    v_new_content := array_remove(v_content, v_debatle_code);
    if v_content <> v_new_content then
       perform data.change_object_and_notify(v_debatles_future_id, 
                                             jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_master_group_id, to_jsonb(v_new_content))),
                                             v_actor_id);
    end if;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_current_id, 'content', v_actor_id), array[]::text[]);
    v_new_content := array_append(v_content, v_debatle_code);
    if v_content <> v_new_content then
     perform data.change_object_and_notify(v_debatles_current_id, 
                                           jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, null, to_jsonb(v_new_content))),
                                           v_actor_id);
    end if;
  elsif v_new_status = 'vote_over' and v_debatle_status = 'vote' and (v_is_master or v_system_debatle_judge = v_actor_id) then
    null; -- не надо переставлять ничего по группам
  elsif v_new_status = 'closed' and v_debatle_status = 'vote_over' and (v_is_master or v_system_debatle_judge = v_actor_id) then
    -- удаляем из текущих у всех, добавляем в завершённые всем (TODO вообще не совсем всем, а только тем, кто в аудиории дебатла)
    perform * from data.objects where id = v_debatles_current_id for update;
    perform * from data.objects where id = v_debatles_closed_id for update;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_current_id, 'content', v_actor_id), array[]::text[]);
    v_new_content := array_remove(v_content, v_debatle_code);
    if v_content <> v_new_content then
       perform data.change_object_and_notify(v_debatles_current_id, 
                                            jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, null, to_jsonb(v_new_content))),
                                            v_actor_id);
    end if;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_closed_id, 'content', v_actor_id), array[]::text[]);
    v_new_content := array_append(v_content, v_debatle_code);
    if v_content <> v_new_content then
      perform data.change_object_and_notify(v_debatles_closed_id, 
                                            jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, null, to_jsonb(v_new_content))),
                                            v_actor_id);
    end if;
-- TODO тут возможно надо ещё менять какие-то статусы участникам дебатла

  elsif v_new_status = 'deleted' and (v_is_master or v_system_debatle_judge = v_actor_id) then
    -- удаляем из черновиков у автора
    -- из неподтверждённых у мастера
    -- из будущих у мастера
    -- из текущих у всех
    -- из закрытых у всех
    -- добавляем в закрытые мастеру
    if v_debatle_status = 'draft' then
      perform * from data.objects where id = v_debatles_draft_id for update;
      v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_draft_id, 'content', v_system_debatle_person1), array[]::text[]);
      v_new_content := array_remove(v_content, v_debatle_code);
      if v_content <> v_new_content then
         perform data.change_object_and_notify(v_debatles_draft_id, 
                                              jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_system_debatle_person1, to_jsonb(v_new_content))),
                                              v_actor_id);
      end if;
    end if;
    if v_debatle_status = 'new' then
      perform * from data.objects where id = v_debatles_new_id for update;
      v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_new_id, 'content', v_master_group_id), array[]::text[]);
      v_new_content := array_remove(v_content, v_debatle_code);
      if v_content <> v_new_content then
         perform data.change_object_and_notify(v_debatles_new_id, 
                                              jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_master_group_id, to_jsonb(v_new_content))),
                                              v_actor_id);
      end if;
    end if;
    if v_debatle_status = 'future' then
      perform * from data.objects where id = v_debatles_future_id for update;
      v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_future_id, 'content', v_master_group_id), array[]::text[]);
      v_new_content := array_remove(v_content, v_debatle_code);
      if v_content <> v_new_content then
         perform data.change_object_and_notify(v_debatles_future_id, 
                                              jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_master_group_id, to_jsonb(v_new_content))),
                                              v_actor_id);
      end if;
    end if;
    if v_debatle_status = 'current' then
      perform * from data.objects where id = v_debatles_current_id for update;
      v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_current_id, 'content', v_actor_id), array[]::text[]);
      v_new_content := array_remove(v_content, v_debatle_code);
      if v_content <> v_new_content then
         perform data.change_object_and_notify(v_debatles_current_id, 
                                              jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, null, to_jsonb(v_new_content))),
                                              v_actor_id);
      end if;
    end if;
    if v_debatle_status = 'closed' then
      perform * from data.objects where id = v_debatles_closed_id for update;
      v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_closed_id, 'content', v_actor_id), array[]::text[]);
      v_new_content := array_remove(v_content, v_debatle_code);
      if v_content <> v_new_content then
         perform data.change_object_and_notify(v_debatles_closed_id, 
                                              jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, null, to_jsonb(v_new_content))),
                                              v_actor_id);
      end if;
    end if;
    perform * from data.objects where id = v_debatles_deleted_id for update;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_deleted_id, 'content', v_master_group_id), array[]::text[]);
    v_new_content := array_append(v_content, v_debatle_code);
    if v_content <> v_new_content then
      perform data.change_object_and_notify(v_debatles_deleted_id, 
                                            jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_master_group_id, to_jsonb(v_new_content))),
                                            v_actor_id);
    end if;

  else
     perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      format('{"action": "show_message", "action_data": {"title": "%s", "message": "%s"}}', 'Ошибка', 'Некорректное изменение статуса дебатла')::jsonb); 
    return;
  end if;

  perform * from data.objects where id = v_debatle_id for update;

  -- если статус поменялся на future, то надо добавить видимость второму участнику и судье
  -- если статус поменялся на vote, то добавить видимость все
  if v_new_status = 'future' then
    if v_system_debatle_person2 <> -1 then 
     v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', v_system_debatle_person2, jsonb 'true'));
    end if;
    if v_system_debatle_judge <> -1 then 
     v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', v_system_debatle_judge, jsonb 'true'));
    end if;
  elsif v_new_status = 'vote' then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', null, jsonb 'true'));
  end if;
  v_changes := array_append(v_changes, data.attribute_change2jsonb('debatle_status', null, to_jsonb(v_new_status)));
  v_message_sent := data.change_current_object(in_client_id,
                                               in_request_id,
                                               v_debatle_id, 
                                               to_jsonb(v_changes));
  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
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
  v_system_debatle_person1 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person1'), -1);

  v_actor_id  integer := data.get_active_actor_id(in_client_id);
  v_is_master boolean := pallas_project.is_in_group(v_actor_id, 'master');
  v_message_sent boolean := false;
  v_system_debatle_theme_attribute_id integer := data.get_attribute_id('system_debatle_theme');
begin
  assert in_request_id is not null;

  if v_title = '' then
    perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      format('{"action": "show_message", "action_data": {"title": "%s", "message": "%s"}}', 'Ошибка', 'Нельзя изменить тему на пустую')::jsonb); 
    return;
  end if;

  if not v_is_master and (v_debatle_status <> 'draft' or v_system_debatle_person1 <> v_actor_id) then
    perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      format('{"action": "show_message", "action_data": {"title": "%s", "message": "%s"}}', 'Ошибка', 'Тему дебатла нельзя изменить на этом этапе')::jsonb); 
    return;
  end if;

  perform * from data.objects o where o.id = v_debatle_id for update;
  if coalesce(data.get_raw_attribute_value(v_debatle_id, v_system_debatle_theme_attribute_id, null), jsonb '"~~~"') <> to_jsonb(v_title) then
    v_message_sent := data.change_current_object(in_client_id, 
                                               in_request_id,
                                               v_debatle_id, 
                                               jsonb_build_array(data.attribute_change2jsonb('system_debatle_theme', null, to_jsonb(v_title))));
  end if;
  if not v_message_sent then
   perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
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

  v_debatle_status text := json.get_string(data.get_attribute_value(v_debatle_id,'debatle_status'));
  v_system_debatle_person1 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person1'), -1);
  v_system_debatle_person2 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person2'), -1);
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

  v_is_master boolean := pallas_project.is_in_group(v_actor_id, 'master');
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

  v_system_debatle_person1_my_vote := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person1_my_vote', v_actor_id), 0);
  v_system_debatle_person2_my_vote := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person2_my_vote', v_actor_id), 0);

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
    v_system_debatle_person1_votes := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person1_votes'), 0);
    v_system_debatle_person2_votes := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person2_votes'), 0);
    v_person1_votes_new := v_system_debatle_person1_votes + v_person1_my_vote_new - v_system_debatle_person1_my_vote;
    v_person2_votes_new := v_system_debatle_person2_votes + v_person2_my_vote_new - v_system_debatle_person2_my_vote;

    if v_system_debatle_person1_my_vote <> v_person1_my_vote_new then 
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person1_my_vote', v_actor_id, to_jsonb(v_person1_my_vote_new)));
    end if;
    if v_system_debatle_person2_my_vote <> v_person2_my_vote_new then 
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person2_my_vote', v_actor_id, to_jsonb(v_person2_my_vote_new)));
    end if;
    if v_system_debatle_person1_votes <> v_person1_votes_new then 
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person1_votes', null, to_jsonb(v_person1_votes_new)));
    end if;
    if v_system_debatle_person2_votes <> v_person2_votes_new then 
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person2_votes', null, to_jsonb(v_person2_votes_new)));
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

  v_actions_list := v_actions_list || ', "' || 'create_random_person":' || 
    '{"code": "create_random_person", "name": "Нажми меня", "disabled": false, "params": {}}';
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
  v_person1_id integer;
  v_person2_id integer;
  v_judge_id integer;
  v_is_master boolean;
  v_debatle_code text;
  v_debatle_status text;
  v_system_debatle_theme_attribute_id integer := data.get_attribute_id('system_debatle_theme');
begin
  assert in_actor_id is not null;

  v_is_master := pallas_project.is_in_group(in_actor_id, 'master');
  v_debatle_code := data.get_object_code(in_object_id);
  v_person1_id := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person1'), null);
  v_person2_id := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person2'), null);
  v_judge_id := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_judge'), null);
  v_debatle_status := json.get_string_opt(data.get_attribute_value(in_object_id, 'debatle_status'), null);

  if v_is_master then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_instigator": {"code": "debatle_change_person", "name": "Изменить зачинщика", "disabled": false, '||
                '"params": {"debatle_code": "%s", "edited_person": "instigator"}}',
                v_debatle_code);
  end if;

  if v_is_master or in_actor_id = v_person1_id and v_debatle_status in ('draft') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_opponent": {"code": "debatle_change_person", "name": "Изменить оппонента", "disabled": false, '||
                '"params": {"debatle_code": "%s", "edited_person": "opponent"}}',
                v_debatle_code);
  end if;

  if v_is_master then
      v_actions_list := v_actions_list || 
        format(', "debatle_change_judge": {"code": "debatle_change_person", "name": "Изменить судью", "disabled": false, '||
                '"params": {"debatle_code": "%s", "edited_person": "judge"}}',
                v_debatle_code);
  end if;

  if v_is_master or in_actor_id = v_person1_id and v_debatle_status in ('draft') then
    v_actions_list := v_actions_list || 
        format(', "debatle_change_theme": {"code": "debatle_change_theme", "name": "Изменить тему", "disabled": false, '||
                '"params": {"debatle_code": "%s"}, "user_params": [{"code": "title", "description": "Введите тему дебатла", "type": "string", "default_value": "%s" }]}',
                v_debatle_code,
                json.get_string_opt(data.get_raw_attribute_value(in_object_id, v_system_debatle_theme_attribute_id, null),''));
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

  if v_is_master and v_debatle_status in ('deleted') or in_actor_id = v_person1_id and v_debatle_status in ('draft') then
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
                json.get_string_opt(data.get_attribute_value(v_person1_id, 'title', in_actor_id), ''),
                case when json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person1_my_vote', in_actor_id), 0) > 0 then 'true' else 'false' end,
                v_debatle_code);
     v_actions_list := v_actions_list || 
        format(', "debatle_vote_person2": {"code": "debatle_vote", "name": "Голосовать за %s", "disabled": %s, '||
                '"params": {"debatle_code": "%s", "voted_person": "opponent"}}',
                json.get_string_opt(data.get_attribute_value(v_person2_id, 'title', in_actor_id), ''),
                case when json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person2_my_vote', in_actor_id), 0) > 0 then 'true' else 'false' end,
                v_debatle_code);
  end if;

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

  if pallas_project.is_in_group(in_actor_id, 'all_person') then
    v_actions_list := v_actions_list || 
      ', "create_debatle_step1": {"code": "create_debatle_step1", "name": "Инициировать дебатл", "disabled": false, '||
      '"params": {}, "user_params": [{"code": "title", "description": "Введите тему дебатла", "type": "string" }]}';
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
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
  v_actions_list text := '';
begin
  assert in_actor_id is not null;

  if data.get_object_code(in_actor_id) = 'anonymous' then
    v_actions_list := v_actions_list || ', "' || 'login":' || 
      '{"code": "login", "name": "Кнопка для мастеров", "disabled": false, "params": {}, "user_params": [{"code": "password", "description": "Введите пароль", "type": "string" }]}';
  else
    if pallas_project.is_in_group(in_actor_id, 'all_person') then
      v_actions_list := v_actions_list || ', "' || 'debatles":' || 
        '{"code": "act_open_object", "name": "Дебатлы", "disabled": false, "params": {"object_code": "debatles"}}';
      v_actions_list := v_actions_list || ', "' || 'logout":' || 
        '{"code": "logout", "name": "Выход", "disabled": false, "params": {}}';
    end if;
  end if;

  return jsonb ('{'||trim(v_actions_list,',')||'}');
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
  v_person1_id integer;
  v_person2_id integer;
  v_judge_id integer;
  v_debatle_theme text;
  v_debatle_status text;

  v_title_attribute_id integer := data.get_attribute_id('title');
  v_debatle_person1_attribute_id integer := data.get_attribute_id('debatle_person1');
  v_debatle_person2_attribute_id integer := data.get_attribute_id('debatle_person2');
  v_debatle_judge_attribute_id integer := data.get_attribute_id('debatle_judge');
  v_debatle_my_vote_attribute_id integer := data.get_attribute_id('debatle_my_vote');
  v_debatle_person1_votes_attribute_id integer := data.get_attribute_id('debatle_person1_votes');
  v_debatle_person2_votes_attribute_id integer := data.get_attribute_id('debatle_person2_votes');

  v_system_debatle_person1_my_vote integer;
  v_system_debatle_person2_my_vote integer;

  v_system_debatle_person1_votes integer;
  v_system_debatle_person2_votes integer;

  v_new_title jsonb;
  v_new_person1 jsonb;
  v_new_person2 jsonb;
  v_new_judge jsonb;
  v_new_debatle_my_vote jsonb;
  v_new_debatle_person1_votes jsonb;
  v_new_debatle_person2_votes jsonb;
begin
  perform * from data.objects where id = in_object_id for update;

  v_debatle_theme := json.get_string_opt(data.get_attribute_value(in_object_id, 'system_debatle_theme'), null);
  v_debatle_status := json.get_string(data.get_attribute_value(in_object_id,'debatle_status'));
  v_person1_id := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person1'), null);
  v_person2_id := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person2'), null);
  v_judge_id := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_judge'), null);

  v_new_title := to_jsonb(format('Дебатл: %s', v_debatle_theme));
  if coalesce(data.get_raw_attribute_value(in_object_id, v_title_attribute_id, in_actor_id), jsonb '"~~~"') <> coalesce(v_new_title, jsonb '"~~~"') then
    perform data.set_attribute_value(in_object_id, v_title_attribute_id, v_new_title, in_actor_id, in_actor_id);
  end if;

  if v_person1_id is not null then
    v_new_person1 := data.get_attribute_value(v_person1_id, v_title_attribute_id, in_actor_id);
  end if;
  if coalesce(data.get_raw_attribute_value(in_object_id, v_debatle_person1_attribute_id, null), jsonb '"~~~"') <> coalesce(v_new_person1, jsonb '"~~~"') then
    perform data.set_attribute_value(in_object_id, v_debatle_person1_attribute_id, v_new_person1, null, in_actor_id);
  end if;

  if v_person2_id is not null then
    v_new_person2 := data.get_attribute_value(v_person2_id, v_title_attribute_id, in_actor_id);
  end if;
  if coalesce(data.get_raw_attribute_value(in_object_id, v_debatle_person2_attribute_id, null), jsonb '"~~~"') <> coalesce(v_new_person2, jsonb '"~~~"') then
    perform data.set_attribute_value(in_object_id, v_debatle_person2_attribute_id, v_new_person2, null, in_actor_id);
  end if;

  if v_judge_id is not null then
    v_new_judge := data.get_attribute_value(v_judge_id, v_title_attribute_id, in_actor_id);
  end if;
  if coalesce(data.get_raw_attribute_value(in_object_id, v_debatle_judge_attribute_id, null), jsonb '"~~~"') <> coalesce(v_new_judge, jsonb '"~~~"') then
    perform data.set_attribute_value(in_object_id, v_debatle_judge_attribute_id, v_new_judge, null, in_actor_id);
  end if;

  --debatle_my_vote
  if v_debatle_status in ('vote', 'vote_over', 'closed') then
    v_system_debatle_person1_my_vote := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person1_my_vote', in_actor_id), 0);
    v_system_debatle_person2_my_vote := json.get_integer_opt(data.get_attribute_value(in_object_id, 'system_debatle_person2_my_vote', in_actor_id), 0);

    if in_actor_id = v_person1_id 
      or in_actor_id = v_person2_id 
      or in_actor_id = v_judge_id 
      or pallas_project.is_in_group(in_actor_id, 'master') then
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

    v_new_debatle_person1_votes := to_jsonb(format('Количество голосов за %s: %s', json.get_string_opt(v_new_person1, 'зачинщика'), v_system_debatle_person1_votes));
    v_new_debatle_person2_votes := to_jsonb(format('Количество голосов за %s: %s', json.get_string_opt(v_new_person2, 'оппонента'), v_system_debatle_person2_votes));

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

-- drop function pallas_project.fcard_debatles(integer, integer);

create or replace function pallas_project.fcard_debatles(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_is_master boolean := pallas_project.is_in_group(in_actor_id, 'master');

  v_content_attribute_id integer := data.get_attribute_id('content');

  v_new_content jsonb;
begin
  perform * from data.objects where id = in_object_id for update;

  if v_is_master then
    v_new_content := to_jsonb(array['debatles_new','debatles_current', 'debutles_future','debatles_closed', 'debatles_all', 'debatles_my']); 
  else
    v_new_content := to_jsonb(array['debatles_my', 'debatles_current', 'debatles_closed']);
  end if;

  if coalesce(data.get_raw_attribute_value(in_object_id, v_content_attribute_id, in_actor_id), to_jsonb(array[]::text[])) <> v_new_content then
    perform data.set_attribute_value(in_object_id, v_content_attribute_id, v_new_content, in_actor_id, in_actor_id);
  end if;
end;
$$
language plpgsql;

-- drop function pallas_project.fcard_menu(integer, integer);

create or replace function pallas_project.fcard_menu(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_is_master boolean := pallas_project.is_in_group(in_actor_id, 'master');

  v_content text[];

  v_changes jsonb[];
begin
  perform * from data.objects where id = in_object_id for update;

  v_content := array['debatles'];

  v_changes := array_append(v_changes, data.attribute_change2jsonb('content', in_actor_id, to_jsonb(v_content)));


  perform data.change_object(in_object_id, to_jsonb(v_changes), in_actor_id);
end;
$$
language plpgsql;

-- drop function pallas_project.fcard_person(integer, integer);

create or replace function pallas_project.fcard_person(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_value jsonb;
  v_is_master boolean;
  v_changes jsonb[];
  v_money_attribute_id integer :=  data.get_attribute_id('money');
  v_system_money_attribute_id integer :=  data.get_attribute_id('system_money');
  v_person_deposit_money_attribute_id integer :=  data.get_attribute_id('person_deposit_money');
  v_system_person_deposit_money_attribute_id integer :=  data.get_attribute_id('system_person_deposit_money');
  v_person_coin_attribute_id integer :=  data.get_attribute_id('person_coin');
  v_system_person_coin_attribute_id integer :=  data.get_attribute_id('system_person_coin');
  v_person_opa_rating_attribute_id integer :=  data.get_attribute_id('person_opa_rating');
  v_system_person_opa_rating_attribute_id integer :=  data.get_attribute_id('system_person_opa_rating');
  v_person_un_rating_attribute_id integer :=  data.get_attribute_id('person_un_rating');
  v_system_person_un_rating_attribute_id integer :=  data.get_attribute_id('system_person_un_rating');
begin
  perform * from data.objects where id = in_object_id for update;

  v_is_master := pallas_project.is_in_group(in_actor_id, 'master');
  if v_is_master or in_object_id = in_actor_id then
    v_value := data.get_attribute_value(in_object_id, v_system_money_attribute_id);
    if data.should_attribute_value_be_changed(in_object_id, v_system_money_attribute_id, null, v_money_attribute_id, in_actor_id) then
      perform data.set_attribute_value(in_object_id, v_money_attribute_id, v_value, in_actor_id, in_actor_id);
    end if;
    v_value := data.get_attribute_value(in_object_id, v_system_person_deposit_money_attribute_id);
    if data.should_attribute_value_be_changed(in_object_id, v_system_person_deposit_money_attribute_id, null, v_person_deposit_money_attribute_id, in_actor_id) then
      perform data.set_attribute_value(in_object_id, v_person_deposit_money_attribute_id, v_value, in_actor_id, in_actor_id);
    end if;
    v_value := data.get_attribute_value(in_object_id, v_system_person_coin_attribute_id);
    if data.should_attribute_value_be_changed(in_object_id, v_system_person_coin_attribute_id, null, v_person_coin_attribute_id, in_actor_id) then
      perform data.set_attribute_value(in_object_id, v_person_coin_attribute_id, v_value, in_actor_id, in_actor_id);
    end if;
    v_value := data.get_attribute_value(in_object_id, v_system_person_opa_rating_attribute_id);
    if data.should_attribute_value_be_changed(in_object_id, v_system_person_opa_rating_attribute_id, null, v_person_opa_rating_attribute_id, in_actor_id) then
      perform data.set_attribute_value(in_object_id, v_person_opa_rating_attribute_id, v_value, in_actor_id, in_actor_id);
    end if;
    v_value := data.get_attribute_value(in_object_id, v_system_person_un_rating_attribute_id);
    if data.should_attribute_value_be_changed(in_object_id, v_system_person_un_rating_attribute_id, null, v_person_un_rating_attribute_id, in_actor_id) then
      perform data.set_attribute_value(in_object_id, v_person_un_rating_attribute_id, v_value, in_actor_id, in_actor_id);
    end if;
  end if;
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
  v_type_attribute_id integer := data.get_attribute_id('type');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_subtitle_attribute_id integer := data.get_attribute_id('subtitle');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_priority_attribute_id integer := data.get_attribute_id('priority');
  v_full_card_function_attribute_id integer := data.get_attribute_id('full_card_function');
  v_mini_card_function_attribute_id integer := data.get_attribute_id('mini_card_function');
  v_actions_function_attribute_id integer := data.get_attribute_id('actions_function');
  v_template_attribute_id integer := data.get_attribute_id('template');

  v_description_attribute_id integer;
  v_system_person_name_attribute_id integer;
  v_person_state_attribute_id integer;
  v_person_occupation_attribute_id integer; 
  v_system_money_attribute_id integer;
  v_money_attribute_id integer;
  v_system_person_deposit_money_attribute_id integer;
  v_person_deposit_money_attribute_id integer;
  v_system_person_coin_attribute_id integer;
  v_person_coin_attribute_id integer;
  v_system_person_opa_rating_attribute_id integer;
  v_person_opa_rating_attribute_id integer;
  v_system_person_un_rating_attribute_id integer;
  v_person_un_rating_attribute_id integer;
  v_person_is_master_attribute_id integer;

  v_all_person_group_id integer;
  v_aster_group_id integer;
  v_un_group_id integer;
  v_mars_group_id integer;
  v_opa_group_id integer;
  v_master_group_id integer;
  v_player_group_id integer;

  v_default_login_id integer;
  v_menu_id integer;
  v_notifications_id integer;
  v_test_id integer;
  v_person_id integer;
  v_person_class_id integer;

  v_template_groups jsonb[];
begin
  insert into data.attributes(code, description, type, card_type, can_be_overridden)
  values('description', 'Текстовый блок с развёрнутым описанием объекта, string', 'normal', 'full', true)
  returning id into v_description_attribute_id;

  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden)
  values ('person_occupation', null, 'Должность', 'normal', null, null, false)
  returning id into v_person_occupation_attribute_id;

  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden)
  values ('person_state', null, 'Гражданство', 'normal', 'full', 'pallas_project.vd_person_state', false)
  returning id into v_person_state_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('system_money', 'Остаток средств на счёте', 'system', null, null, false)
  returning id into v_system_money_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('money', 'Остаток средств на счёте', 'normal', 'full', null, true)
  returning id into v_money_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('system_person_deposit_money', 'Остаток средств на накопительном счёте', 'system', null, null, false)
  returning id into v_system_person_deposit_money_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('person_deposit_money', 'Остаток средств на накопительном счёте', 'normal', 'full', null, true)
  returning id into v_person_deposit_money_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('system_person_coin', 'Остаток коинов', 'system', null, null, false)
  returning id into v_system_person_coin_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('person_coin', 'Остаток коинов', 'normal', 'full', null, true)
  returning id into v_person_coin_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('system_person_opa_rating', 'Рейтинг в СВП', 'system', null, null, false)
  returning id into v_system_person_opa_rating_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('person_opa_rating', 'Рейтинг в СВП', 'normal', 'full', null, true)
  returning id into v_person_opa_rating_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('system_person_un_rating', 'Рейтинг в ООН', 'system', null, null, false)
  returning id into v_system_person_un_rating_attribute_id;

  insert into data.attributes(code, name, type, card_type, value_description_function, can_be_overridden)
  values ('person_un_rating', 'Рейтинг в ООН', 'normal', 'full', null, true)
  returning id into v_person_un_rating_attribute_id;

  -- Создадим актора по умолчанию, который является первым тестом
  insert into data.objects(code) values('anonymous') returning id into v_test_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_title_attribute_id, jsonb '"Unknown"'),
  (v_test_id, v_actions_function_attribute_id,'"pallas_project.actgenerator_anonymous"'),
  (v_test_id, v_template_attribute_id, jsonb_build_object('groups', array[format(
                                      '{"code": "%s", "actions": ["%s"]}',
                                      'group1',
                                      'create_random_person')::jsonb]));

  -- Логин по умолчанию
  insert into data.logins(code) values('default_login') returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_test_id);

  insert into data.params(code, value, description) values
  ('default_login_id', to_jsonb(v_default_login_id), 'Идентификатор логина по умолчанию'),
  ('first_names', to_jsonb(string_to_array('Джон Джек Пол Джордж Билл Кевин Уильям Кристофер Энтони Алекс Джош Томас Фред Филипп Джеймс Брюс Питер Рональд Люк Энди Антонио Итан Сэм Марк Карл Роберт'||
  ' Эльза Лидия Лия Роза Кейт Тесса Рэйчел Амали Шарлотта Эшли София Саманта Элоиз Талия Молли Анна Виктория Мария Натали Келли Ванесса Мишель Элизабет Кимберли Кортни Лоис Сьюзен Эмма', ' ')), 'Список имён'),
  ('last_names', to_jsonb(string_to_array('Янг Коннери Питерс Паркер Уэйн Ли Максуэлл Калвер Кэмерон Альба Сэндерсон Бэйли Блэкшоу Браун Клеменс Хаузер Кендалл Патридж Рой Сойер Стоун Фостер Хэнкс Грегг'||
  ' Флинн Холл Винсон Уайтинг Хасси Хейвуд Стивенс Робинсон Йорк Гудман Махони Гордон Вуд Рид Грэй Тодд Иствуд Брукс Бродер Ховард Смит Нельсон Синклер Мур Тернер Китон Норрис', ' ')), 'Список фамилий');

  -- Также для работы нам понадобится объект меню
  insert into data.objects(code) values('menu') returning id into v_menu_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_menu_id, v_type_attribute_id, jsonb '"menu"'),
  (v_menu_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_menu_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_menu"'),
  (v_menu_id, v_template_attribute_id, jsonb_build_object('groups', array[format(
                                      '{"code": "%s", "actions": ["%s", "%s", "%s"]}',
                                      'menu_group1',
                                      'login',
                                      'debatles',
                                      'logout')::jsonb]));

  -- И пустой список уведомлений
  insert into data.objects(code) values('notifications') returning id into v_notifications_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_notifications_id, v_type_attribute_id, jsonb '"notifications"'),
  (v_notifications_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_notifications_id, v_content_attribute_id, jsonb '[]');

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

  insert into data.actions(code, function) values
  ('act_open_object', 'pallas_project.act_open_object'),
  ('login', 'pallas_project.act_login'),
  ('logout', 'pallas_project.act_logout'),
  ('go_back', 'pallas_project.act_go_back'),
  ('create_random_person', 'pallas_project.act_create_random_person');

  --Объект класса для персон
  insert into data.objects(code, type) values('person', 'class') returning id into v_person_class_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_class_id, v_type_attribute_id, jsonb '"person"'),
  (v_person_class_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_person_class_id, v_full_card_function_attribute_id, jsonb '"pallas_project.fcard_person"'),
  (v_person_class_id, v_mini_card_function_attribute_id, jsonb '"pallas_project.mcard_person"'),
  (v_person_class_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_menu"'),
  (v_person_class_id, v_template_attribute_id, jsonb_build_object('groups', array[format(
                                                      '{"code": "%s", "attributes": ["%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s"]}',
                                                      'person_group1',
                                                      'person_state',
                                                      'person_occupation',
                                                      'money',
                                                      'person_deposit_money',
                                                      'person_coin',
                                                      'person_opa_rating',
                                                      'person_un_rating',
                                                      'description')::jsonb]));

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text 'Добрый день!')
  );

  -- Группы персон
  insert into data.objects(code) values ('all_person') returning id into v_all_person_group_id;
  insert into data.objects(code) values ('aster') returning id into v_aster_group_id;
  insert into data.objects(code) values ('un') returning id into v_un_group_id;
  insert into data.objects(code) values ('mars') returning id into v_mars_group_id;
  insert into data.objects(code) values ('opa') returning id into v_opa_group_id;
  insert into data.objects(code) values ('master') returning id into v_master_group_id;
  insert into data.objects(code) values ('player') returning id into v_player_group_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_all_person_group_id, v_priority_attribute_id, jsonb '10'),
  (v_player_group_id, v_priority_attribute_id, jsonb '15'),
  (v_aster_group_id, v_priority_attribute_id, jsonb '20'),
  (v_un_group_id, v_priority_attribute_id, jsonb '30'),
  (v_mars_group_id, v_priority_attribute_id, jsonb '40'),
  (v_opa_group_id, v_priority_attribute_id, jsonb '50'),
  (v_master_group_id, v_priority_attribute_id, jsonb '190');
/*
  -- Данные персон
  insert into data.objects(code, class_id) values('person1', v_person_class_id) returning id into v_person_id;
    -- Логин
  insert into data.logins(code) values('p1') returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_person_id);
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_id, v_title_attribute_id, jsonb '"Джерри Адамс"'),
  (v_person_id, v_priority_attribute_id, jsonb '200'),
  (v_person_id, v_person_state_attribute_id, jsonb '"un"'),
  (v_person_id, v_person_occupation_attribute_id, jsonb '"Секретарь администрации"'),
  (v_person_id, v_system_money_attribute_id, jsonb '0'),
  (v_person_id, v_system_person_coin_attribute_id, jsonb '50'),
  (v_person_id, v_system_person_opa_rating_attribute_id, jsonb '1'),
  (v_person_id, v_system_person_un_rating_attribute_id, jsonb '150');

  insert into data.object_objects(parent_object_id, object_id) values
  (v_all_person_group_id, v_person_id),
  (v_un_group_id, v_person_id),
  (v_player_group_id, v_person_id);
*/
  insert into data.objects(code, class_id) values('person2', v_person_class_id) returning id into v_person_id;
    -- Логин
  insert into data.logins(code) values('p2') returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_person_id);
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_id, v_title_attribute_id, jsonb '"Саша"'),
  (v_person_id, v_person_occupation_attribute_id, jsonb '"Мастер"'),
  (v_person_id, v_priority_attribute_id, jsonb '200');

  insert into data.object_objects(parent_object_id, object_id) values
  (v_all_person_group_id, v_person_id),
  (v_master_group_id, v_person_id);
/*
insert into data.objects(code, class_id) values('person3', v_person_class_id) returning id into v_person_id;
    -- Логин
  insert into data.logins(code) values('p3') returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_person_id);
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_id, v_title_attribute_id, jsonb '"Сьюзан Сидорова"'),
  (v_person_id, v_priority_attribute_id, jsonb '200'),
  (v_person_id, v_person_state_attribute_id, jsonb '"aster"'),
  (v_person_id, v_person_occupation_attribute_id, jsonb '"Шахтёр"'),
  (v_person_id, v_system_money_attribute_id, jsonb '65000'),
  (v_person_id, v_system_person_opa_rating_attribute_id, jsonb '5'),
  (v_person_id, v_system_person_un_rating_attribute_id, jsonb '0');

  insert into data.object_objects(parent_object_id, object_id) values
  (v_all_person_group_id, v_person_id),
  (v_opa_group_id, v_person_id),
  (v_player_group_id, v_person_id),
  (v_aster_group_id, v_person_id);
*/
  perform pallas_project.init_debatles();
end;
$$
language plpgsql;

-- drop function pallas_project.init_debatles();

create or replace function pallas_project.init_debatles()
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


  v_debatles_id integer;
  v_debatle_list_class_id integer;
  v_debatles_all_id integer;
  v_debatles_new_id integer;
  v_debatles_my_id integer;
  v_debatles_future_id integer;
  v_debatles_closed_id integer;
  v_debatles_current_id integer;
  v_debatles_draft_id integer;
  v_debatles_deleted_id integer;

  v_debatle_class_id integer;
  v_debatle_temp_person_list_class_id integer;

  v_master_group_id integer := data.get_object_id('master');

begin
  -- Атрибуты для дебатла
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('system_debatle_theme', null, 'Тема дебатла', 'system', null, null, false),
  ('debatle_status', 'Статус', null, 'normal', null, 'pallas_project.vd_debatle_status', false),
  ('system_debatle_person1', null, 'Идентификатор первого участника дебатла', 'system', null, null, false),
  ('debatle_person1', 'Зачинщик', null, 'normal', 'full', null, false),
  ('system_debatle_person2', null, 'Идентификатор второго участника дебатла', 'system', null, null, false),
  ('debatle_person2', 'Оппонент', null, 'normal', 'full', null, false),
  ('system_debatle_judge', null, 'Идентификатор судьи', 'system', null, null, false),
  ('debatle_judge', 'Судья', null, 'normal', 'full', null, false),
  ('system_debatle_target_audience', null, 'Аудитория дебатла', 'system', null, null, false),
  ('debatle_target_audience', 'Аудитория', null, 'normal', 'full', null, true),
  ('system_debatle_person1_votes', null, 'Количество голосов за первого участника', 'system', null, null, false),
  ('debatle_person1_votes', null, 'Количество голосов за первого участника', 'normal', 'full', null, true),
  ('system_debatle_person2_votes', null, 'Количество голосов за второго участника', 'system', null, null, false),
  ('debatle_person2_votes', null, 'Количество голосов за второго участника', 'normal', 'full', null, true),
  ('debatle_vote_price', 'Стоимость голосования', null, 'normal', 'full', null, true),
  ('system_debatle_person1_bonuses', null, 'Бонусы первого участника', 'system', null, null, false),
  ('debatle_person1_bonuses', 'Бонусы зачинщика', null, 'normal', 'full', null, true),
  ('system_debatle_person1_fines' , null, 'Штрафы первого участника', 'system', null, null, false),
  ('debatle_person1_fines', 'Штрафы зачинщика', null, 'normal', 'full', null, true),
  ('system_debatle_person2_bonuses', null, 'Бонусы второго участника', 'system', null, null, false),
  ('debatle_person2_bonuses', 'Бонусы оппонента', null, 'normal', 'full', null, true),
  ('system_debatle_person2_fines', null, 'Штрафы второго участника', 'system', null, null, false),
  ('debatle_person2_fines', 'Штрафы оппонента', null, 'normal', 'full', null, true),
  ('system_debatle_person1_my_vote', null, 'Количество голосов каждого голосующего за первого участника', 'system', null, null, true),
  ('system_debatle_person2_my_vote', null, 'Количество голосов каждого голосующего за второго участника', 'system', null, null, true),
  ('debatle_my_vote', null, 'Уведомление игрока о том, за кого от проголосовал', 'normal', 'full', null, true),
  -- для временных объектов 
  ('debatle_temp_person_list_edited_person', null, 'Редактируемая персона в дебатле', 'normal', 'full', 'pallas_project.vd_debatle_temp_person_list_edited_person', false),
  ('system_debatle_temp_person_list_debatle_id', null, 'Идентификатор дебатла для списка редактирования персон', 'system', null, null, false);

-- Объект - страница для работы с дебатлами
  insert into data.objects(code) values('debatles') returning id into v_debatles_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_debatles_id, v_type_attribute_id, jsonb '"debatles"'),
  (v_debatles_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_debatles_id, v_title_attribute_id, jsonb '"Дебатлы"'),
  (v_debatles_id, v_full_card_function_attribute_id, jsonb '"pallas_project.fcard_debatles"'),
  (v_debatles_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_debatles"'),
  (v_debatles_id, v_template_attribute_id, jsonb_build_object('groups', array[format(
                                          '{"code": "%s", "attributes": ["%s"], "actions": ["%s"]}',
                                          'debatles_group1',
                                          'description',
                                          'create_debatle_step1')::jsonb]));

    -- Объект-класс для списка дебатлов
  insert into data.objects(code, type) values('debatle_list', 'class') returning id into v_debatle_list_class_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_debatle_list_class_id, v_type_attribute_id, jsonb '"debatle_list"'),
  (v_debatle_list_class_id, v_template_attribute_id, jsonb_build_object('groups', array[]::text[]));


  -- Списки дебатлов
  insert into data.objects(code, class_id) values ('debatles_all', v_debatle_list_class_id) returning id into v_debatles_all_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_all_id, v_title_attribute_id, jsonb '"Все дебатлы"', null),
  (v_debatles_all_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id);

  insert into data.objects(code, class_id) values ('debatles_draft', v_debatle_list_class_id) returning id into v_debatles_draft_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_draft_id, v_title_attribute_id, jsonb '"Дебатлы черновики"', null),
  (v_debatles_draft_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id);

  insert into data.objects(code, class_id) values ('debatles_new', v_debatle_list_class_id) returning id into v_debatles_new_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_new_id, v_title_attribute_id, jsonb '"Неподтверждённые дебатлы"', null),
  (v_debatles_new_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id);

  insert into data.objects(code, class_id) values ('debatles_my', v_debatle_list_class_id) returning id into v_debatles_my_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_my_id, v_title_attribute_id, jsonb '"Мои дебатлы"', null),
  (v_debatles_my_id, v_is_visible_attribute_id, jsonb 'true', null);

  insert into data.objects(code, class_id) values ('debatles_future', v_debatle_list_class_id) returning id into v_debatles_future_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_future_id, v_title_attribute_id, jsonb '"Будущие дебатлы"', null),
  (v_debatles_future_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id);

  insert into data.objects(code, class_id) values ('debatles_current', v_debatle_list_class_id) returning id into v_debatles_current_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_current_id, v_title_attribute_id, jsonb '"Текущие дебатлы"', null),
  (v_debatles_current_id, v_is_visible_attribute_id, jsonb 'true', null);

  insert into data.objects(code, class_id) values ('debatles_closed', v_debatle_list_class_id) returning id into v_debatles_closed_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_closed_id, v_title_attribute_id, jsonb '"Завершенные дебатлы"', null),
  (v_debatles_closed_id, v_is_visible_attribute_id, jsonb 'true', null);

  insert into data.objects(code, class_id) values ('debatles_deleted', v_debatle_list_class_id) returning id into v_debatles_deleted_id;
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatles_deleted_id, v_title_attribute_id, jsonb '"Удалённые дебатлы"', null),
  (v_debatles_deleted_id, v_is_visible_attribute_id, jsonb 'true', null);

  -- Объект-класс для дебатла
  insert into data.objects(code, type) values('debatle', 'class') returning id into v_debatle_class_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_debatle_class_id, v_type_attribute_id, jsonb '"debatle"'),
  (v_debatle_class_id, v_full_card_function_attribute_id, jsonb '"pallas_project.fcard_debatle"'),
  (v_debatle_class_id, v_mini_card_function_attribute_id, jsonb '"pallas_project.mcard_debatle"'),
  (v_debatle_class_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_debatle"'),
  (v_debatle_class_id, v_template_attribute_id, jsonb_build_object('groups', array[format(
                                                      '{"code": "%s", "attributes": ["%s", "%s", "%s", "%s", "%s", "%s"], 
                                                                      "actions": ["%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s"]}',
                                                      'debatle_group1',
                                                      'debatle_theme',
                                                      'debatle_status',
                                                      'debatle_person1',
                                                      'debatle_person2',
                                                      'debatle_judge',
                                                      'debatle_target_audience',
                                                      'debatle_change_instigator',
                                                      'debatle_change_opponent',
                                                      'debatle_change_judge',
                                                      'debatle_change_theme',
                                                      'debatle_change_status_new',
                                                      'debatle_change_status_future',
                                                      'debatle_change_status_vote',
                                                      'debatle_change_status_vote_over',
                                                      'debatle_change_status_closed',
                                                      'debatle_change_status_deleted')::jsonb,
                                                      format(
                                                      '{"code": "%s", "attributes": ["%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s"], 
                                                                      "actions": ["%s", "%s"]}',
                                                      'debatle_group2',
                                                      'debatle_person1_votes',
                                                      'debatle_person2_votes',
                                                      'debatle_vote_price',
                                                      'debatle_person1_bonuses',
                                                      'debatle_person1_fines',
                                                      'debatle_person2_bonuses',
                                                      'debatle_person2_fines',
                                                      'debatle_my_vote',
                                                      'debatle_vote_person1',
                                                      'debatle_vote_person2')::jsonb]));

  -- Объект-класс для временных списков персон для редактирования дебатла
  insert into data.objects(code, type) values('debatle_temp_person_list', 'class') returning id into v_debatle_temp_person_list_class_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_debatle_temp_person_list_class_id, v_type_attribute_id, jsonb '"debatle_temp_person_list"'),
  (v_debatle_temp_person_list_class_id, v_actions_function_attribute_id, jsonb '"pallas_project.actgenerator_debatle_temp_person_list"'),
  (v_debatle_temp_person_list_class_id, v_list_element_function_attribute_id, jsonb '"pallas_project.lef_debatle_temp_person_list"'),
  (v_debatle_temp_person_list_class_id, v_temporary_object_attribute_id, jsonb 'true'),
  (v_debatle_temp_person_list_class_id, v_template_attribute_id, jsonb_build_object('groups', format(
                                                      '[{"code": "%s", "actions": ["%s"]}, {"code": "%s", "attributes": ["%s"]}]',
                                                      'group1',
                                                      'debatle_change_person_back',
                                                      'group2',
                                                      'debatle_temp_person_list_edited_person')::jsonb));

  insert into data.actions(code, function) values
  ('create_debatle_step1', 'pallas_project.act_create_debatle_step1'),
  ('debatle_change_person', 'pallas_project.act_debatle_change_person'),
  ('debatle_change_theme', 'pallas_project.act_debatle_change_theme'),
  ('debatle_change_status', 'pallas_project.act_debatle_change_status'),
  ('debatle_vote', 'pallas_project.act_debatle_vote');


end;
$$
language plpgsql;

-- drop function pallas_project.is_in_group(integer, text);

create or replace function pallas_project.is_in_group(in_object_id integer, in_group_code text)
returns boolean
volatile
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

-- drop function pallas_project.lef_debatle_temp_person_list(integer, text, integer, integer);

create or replace function pallas_project.lef_debatle_temp_person_list(in_client_id integer, in_request_id text, object_id integer, list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);
  v_edited_person text := json.get_string(data.get_attribute_value(object_id, 'debatle_temp_person_list_edited_person'));
  v_debatle_id integer := json.get_integer(data.get_attribute_value(object_id, 'system_debatle_temp_person_list_debatle_id'));
  v_debatle_code text := data.get_object_code(v_debatle_id);

  v_system_debatle_person1 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person1'), -1);
  v_system_debatle_person2 integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_person2'), -1);
  v_system_debatle_judge integer := json.get_integer_opt(data.get_attribute_value(v_debatle_id, 'system_debatle_judge'), -1);
  v_debatle_status text := json.get_string(data.get_attribute_value(v_debatle_id, 'debatle_status'));

  v_old_person integer;

  v_debatles_my_id integer := data.get_object_id('debatles_my');

  v_content_attribute_id integer := data.get_attribute_id('content');

  v_content text[];
  v_new_content text[];
  v_changes jsonb[];

  v_change_debatles_my jsonb[]; 
begin
  assert in_request_id is not null;
  assert list_object_id is not null;

  if v_edited_person not in ('instigator', 'opponent', 'judge') then
    perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      format('{"action": "show_message ", "action_data": {"title": "%s", "message": "%s"}}', 'Ошибка', 'Непонятно, какую из персон менять. Наверное что-то пошло не так. Обратитесь к мастеру.')::jsonb); 
    return;
  end if;

  perform * from data.objects where id = v_debatle_id for update;

  if v_edited_person = 'instigator' then
    v_old_person := v_system_debatle_person1;
    if v_old_person <> list_object_id then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person1', null, to_jsonb(list_object_id)));
    end if;
  elsif v_edited_person = 'opponent' then
    v_old_person := v_system_debatle_person2;
    if v_old_person <> list_object_id then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_person2', null, to_jsonb(list_object_id)));
    end if;
  elsif v_edited_person = 'judge' then
    v_old_person := v_system_debatle_judge;
    if v_old_person <> list_object_id then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('system_debatle_judge', null, to_jsonb(list_object_id)));
    end if;
  end if;

  -- TODO тут по идее ещё надо проверять, что персона не попадает в аудиторию дебатла, и тогда тоже убирать даже в случае публичных статусов
  if v_old_person <> -1 
  and v_debatle_status not in ('vote', 'vote_over', 'closed') then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', v_old_person, null::jsonb));
  end if;
  if v_edited_person = 'instigator' 
    or (v_edited_person in ('opponent','judge') and v_debatle_status in ('future', 'vote', 'vote_over', 'closed')) then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('is_visible', list_object_id, jsonb 'true'));
  end if;
  perform data.change_object_and_notify(v_debatle_id, to_jsonb(v_changes), v_actor_id);

  if v_old_person <> list_object_id and v_old_person <> -1 then
    --Удаляем из моих дебатлов у старой персоны,
    perform * from data.objects where id = v_debatles_my_id for update;
    v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_my_id, 'content', v_old_person), array[]::text[]);
    v_new_content := array_remove(v_content, v_debatle_code);
    if v_content <> v_new_content then
      v_change_debatles_my := array_append(v_change_debatles_my, data.attribute_change2jsonb(v_content_attribute_id, v_old_person, to_jsonb(v_new_content)));
    end if;
  end if;
  -- Добавляем в мои дебатлы новой персоне
  v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_my_id, 'content', list_object_id), array[]::text[]);
  v_new_content := array_append(v_content, v_debatle_code);
  if v_content <> v_new_content then
    v_change_debatles_my := array_append(v_change_debatles_my, data.attribute_change2jsonb(v_content_attribute_id, list_object_id, to_jsonb(v_new_content)));
  end if;
  if array_length(v_change_debatles_my, 1) > 0 then
    perform data.change_object_and_notify(v_debatles_my_id, 
                                          to_jsonb(v_change_debatles_my),
                                          v_actor_id);
  end if;

  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'action',
    '{"action": "go_back", "action_data": {}}'::jsonb);
end;
$$
language plpgsql;

-- drop function pallas_project.mcard_debatle(integer, integer);

create or replace function pallas_project.mcard_debatle(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_new_title jsonb;
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_debatle_theme text;

  begin
  perform * from data.objects where id = in_object_id for update;

  v_debatle_theme := json.get_string_opt(data.get_attribute_value(in_object_id, 'system_debatle_theme'), null);
  v_new_title := to_jsonb(format('%s', v_debatle_theme));
  if coalesce(data.get_raw_attribute_value(in_object_id, v_title_attribute_id, in_actor_id), jsonb '"~~~"') <>  coalesce(v_new_title, jsonb '"~~~"') then
    perform data.set_attribute_value(in_object_id, v_title_attribute_id, v_new_title, in_actor_id, in_actor_id);
  end if;

end;
$$
language plpgsql;

-- drop function pallas_project.mcard_person(integer, integer);

create or replace function pallas_project.mcard_person(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_value jsonb;
  v_is_master boolean;
  v_changes jsonb[];
begin

  null;

end;
$$
language plpgsql;

-- drop function pallas_project.vd_debatle_status(integer, jsonb, integer);

create or replace function pallas_project.vd_debatle_status(in_attribute_id integer, in_value jsonb, in_actor_id integer)
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

-- drop function pallas_project.vd_debatle_temp_person_list_edited_person(integer, jsonb, integer);

create or replace function pallas_project.vd_debatle_temp_person_list_edited_person(in_attribute_id integer, in_value jsonb, in_actor_id integer)
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
  when v_text_value = 'vote_over' then
  else
    return 'Что-то пошло не так';
  end case;
end;
$$
language plpgsql;

-- drop function pallas_project.vd_person_state(integer, jsonb, integer);

create or replace function pallas_project.vd_person_state(in_attribute_id integer, in_value jsonb, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'un' then
    return 'Гражданин ООН';
  when v_text_value = 'aster' then
    return 'Астер';
  when v_text_value = 'mars' then
    return 'Марсианин';
  else
    return 'Неизвестно';
  end case;
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
    v_changes := v_changes || data.attribute_change2jsonb('test_state', null, jsonb '"state2"');
    v_changes := v_changes || data.attribute_change2jsonb('title', null, to_jsonb(v_title));
    v_changes := v_changes || data.attribute_change2jsonb('description', null, to_jsonb(
'**Проверка 1:** Заголовок изменился на "' || v_title || '".
**Проверка 2:** Название кнопки поменялось на "Вперёд!".
**Проверка 3:** Действие в очередной раз полностью меняет отображаемые данные.'));
  elsif v_state = 'state2' then
    v_changes := v_changes || data.attribute_change2jsonb('test_state', null, jsonb '"state3"');
    v_changes := v_changes || data.attribute_change2jsonb('title', null, to_jsonb(v_title));
    v_changes := v_changes || data.attribute_change2jsonb('subtitle', null, jsonb '"Тест на удаление и добавление атрибутов"');
    v_changes := v_changes || data.attribute_change2jsonb('description', null, null);
    v_changes := v_changes || data.attribute_change2jsonb('template', null, jsonb '{"groups": [{"code": "not_so_common", "attributes": ["description2"]}]}');
    v_changes := v_changes || data.attribute_change2jsonb('description2', null, to_jsonb(text
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
    (v_test_id, v_short_attr_id, null),
    (v_test_id, v_long_attr_id, null),
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
**Проверка 8:** У третьего элемента есть заголовок "Далее" и какой-то текст.')
  );

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
  set value = jsonb_build_object('groups', to_jsonb(v_template_groups))
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
  v_object_code text := data.get_object_code(in_object_id);
  v_list_object_code text := data.get_object_code(in_list_object_id);
  v_list_object_title text := json.get_string_opt(data.get_attribute_value(in_list_object_id, 'title', v_actor_id), null);
begin
  assert in_request_id is not null;

  if v_list_object_title = 'Далее' then
    perform api_utils.create_open_object_action_notification(
      in_client_id,
      in_request_id,
      test_project.next_code(v_object_code));
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
  (v_object_id, data.get_attribute_id('template'), jsonb '{"groups": [{"code": "main", "attributes": ["description2"]}]}'),
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
  (v_object_id, data.get_attribute_id('short_card_attribute'), null),
  (v_object_id, data.get_attribute_id('attribute_with_description'), jsonb '"значение"'),
  (v_object_id, data.get_attribute_id('attribute'), jsonb '"значение"'),
  (v_object_id, data.get_attribute_id('template'), jsonb '{"groups": [{"code": "main", "attributes": ["description2"]}, {"code": "additional", "name": "Группа элемента списка", "attributes": ["short_card_attribute", "attribute_with_description", "attribute"], "actions": ["action"]}]}'),
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
  (v_object_id, data.get_attribute_id('template'), jsonb '{"groups": [{"code": "main", "attributes": ["description2"]}]}'),
  (v_object_id, data.get_attribute_id('description2'), jsonb '"Ничтоже сумняшеся выбираем этот элемент для перехода к следующему тесту"');

  -- Заполняем параметры оригинального объекта

  perform data.set_attribute_value(in_object_id, data.get_attribute_id('content'), v_content, null, in_actor_id);
  perform data.set_attribute_value(in_object_id, data.get_attribute_id('list_element_function'), jsonb '"test_project.next_or_do_nothing_list_action"', null, in_actor_id);
end;
$$
language plpgsql;

-- drop function test_project.test_value_description_function(integer, jsonb, integer);

create or replace function test_project.test_value_description_function(in_attribute_id integer, in_value jsonb, in_actor_id integer)
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
  value jsonb,
  start_time timestamp with time zone not null default clock_timestamp(),
  start_reason text,
  start_actor_id integer,
  constraint attribute_values_pk primary key(id),
  constraint attribute_values_value_object_check check((value_object_id is null) or (data.is_instance(object_id) and data.can_attribute_be_overridden(attribute_id) and data.is_instance(value_object_id)))
);

comment on column data.attribute_values.value_object_id is 'Объект, для которого переопределено значение атрибута. В случае, если видно несколько переопределённых значений, выбирается значение для объекта с наивысшим приоритетом.';

-- drop table data.attribute_values_journal;

create table data.attribute_values_journal(
  id integer not null generated always as identity,
  object_id integer not null,
  attribute_id integer not null,
  value_object_id integer,
  value jsonb,
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
comment on column data.attributes.value_description_function is 'Имя функции для получения описания значения атрибута. Функция вызывается с параметрами (attribute_id, value, actor_id).
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
  constraint client_subscription_objects_unique_csi_i unique(client_subscription_id, index),
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

-- drop table data.notifications;

create table data.notifications(
  id integer not null generated always as identity,
  code text not null default (pgcrypto.gen_random_uuid())::text,
  message jsonb not null,
  client_id integer not null,
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
  end_time timestamp with time zone not null,
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

alter table data.object_objects_journal add constraint object_objects_journal_fk_object
foreign key(object_id) references data.objects(id);

alter table data.object_objects_journal add constraint object_objects_journal_fk_parent_object
foreign key(parent_object_id) references data.objects(id);

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

select test_project.init();

analyze;