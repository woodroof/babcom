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
language 'plpgsql';

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

-- drop schema data;

create schema data;

-- drop schema error;

create schema error;

-- drop schema json;

create schema json;

-- drop schema json_test;

create schema json_test;

-- drop schema random;

create schema random;

-- drop schema random_test;

create schema random_test;

-- drop schema test;

create schema test;

-- drop schema test_project;

create schema test_project;

-- Creating enums

-- drop type api_utils.output_message_type;

create type api_utils.output_message_type as enum(
  'action',
  'actors',
  'diff',
  'object',
  'object_list');

-- drop type data.attribute_type;

create type data.attribute_type as enum(
  'system',
  'hidden',
  'normal');

-- drop type data.card_type;

create type data.card_type as enum(
  'full',
  'mini');

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
  v_request_id text := json.get_string(in_message, 'request_id');
  v_type text := json.get_string(in_message, 'type');
  v_client_id integer;
  v_login_id integer;
  v_check_result boolean;
begin
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

  loop
    begin
      if v_type = 'get_actors' then
        perform api_utils.process_get_actors_message(v_client_id, v_request_id);
      elsif v_type = 'set_actor' then
        perform api_utils.process_set_actor_message(v_client_id, json.get_object(in_message, 'data'));
      elsif v_type = 'subscribe' then
        perform api_utils.process_subscribe_message(v_client_id, v_request_id, json.get_object(in_message, 'data'));
      elsif v_type = 'get_more' then
        perform api_utils.process_get_more_message(v_client_id, v_request_id, json.get_object(in_message, 'data'));
      elsif v_type = 'unsubscribe' then
        perform api_utils.process_unsubscribe_message(v_client_id, json.get_object(in_message, 'data'));
      elsif v_type = 'make_action' then
        perform api_utils.process_make_action_message(v_client_id, v_request_id, json.get_object(in_message, 'data'));
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
  end;
end;
$$
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

-- drop function api_utils.process_get_actors_message(integer, text);

create or replace function api_utils.process_get_actors_message(in_client_id integer, in_request_id text)
returns void
volatile
as
$$
declare
  v_login_id integer;
  v_actor_function text;
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
    select json.get_string_opt(data.get_attribute_value(actor_id, 'actor_function'), null) as actor_function
    from data.login_actors
    where login_id = v_login_id
    for share
  loop
    if v_actor_function is not null then
      execute format('select %s($1)', v_actor_function)
      using v_actor_id;
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
language 'plpgsql';

-- drop function api_utils.process_get_more_message(integer, integer, jsonb);

create or replace function api_utils.process_get_more_message(in_client_id integer, in_request_id integer, in_message jsonb)
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
  where object_id = v_object_id
  for update;

  v_list := data.get_next_list(in_client_id, v_object_id);

  perform api_utils.create_notification(in_client_id, in_request_id, 'object_list', jsonb_build_object('list', v_list));
end;
$$
language 'plpgsql';

-- drop function api_utils.process_make_action_message(integer, integer, jsonb);

create or replace function api_utils.process_make_action_message(in_client_id integer, in_request_id integer, in_message jsonb)
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
begin
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

  select function
  into v_function
  from data.actions
  where code = v_action_code;

  if v_function is null then
    raise exception 'Function with code % not found', v_action_code;
  end if;

  execute format('select %s($1, $2, $3, $4)', v_function)
  using in_request_id, v_actor_id, v_params, v_user_params;
end;
$$
language 'plpgsql';

-- drop function api_utils.process_set_actor_message(integer, jsonb);

create or replace function api_utils.process_set_actor_message(in_client_id integer, in_message jsonb)
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
end;
$$
language 'plpgsql';

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
    perform data.log('error', format('Attempt to subscribe for non-existing object'' changes with code %s. Redirecting to 404.', v_object_code));

    v_object_id := data.get_integer_param('not_found_object_id');

    select true
    into v_object_exists
    from data.objects
    where id = v_object_id
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
      where id = v_object_id
      for update;

      if v_object_exists is null then
        raise exception 'Object % not found', v_object_id;
      end if;

      continue;
    end if;

    -- Проверяем видимость
    v_is_visible := json.get_boolean_opt(data.get_attribute_value(v_object_id, 'is_visible', v_actor_id), null);
    if v_is_visible is null then
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

  if v_subscription_exists is true then
    raise exception 'Can''t create second subscription to object %', v_object_id;
  end if;

  insert into data.client_subscriptions(client_id, object_id)
  values(in_client_id, v_object_id);

  v_object := data.get_object(v_object_id, v_actor_id, 'full', v_object_id);

  perform api_utils.create_notification(in_client_id, in_request_id, 'object', v_object);
end;
$$
language 'plpgsql';

-- drop function api_utils.process_unsubscribe_message(integer, jsonb);

create or replace function api_utils.process_unsubscribe_message(in_client_id integer, in_message jsonb)
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
end;
$$
language 'plpgsql';

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
  assert in_object_id is not null;
  assert in_parent_object_id is not null;

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
language 'plpgsql';

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
language 'plpgsql';

-- drop function data.filter_template(jsonb, jsonb, jsonb);

create or replace function data.filter_template(in_template jsonb, in_attributes jsonb, in_actions jsonb)
returns jsonb
immutable
as
$$
declare
  v_groups jsonb := json.get_array(json.get_object(in_template), 'groups');
  v_group jsonb;
  v_attribute_name text;
  v_action_name text;
  v_name text;
  v_filtered_group jsonb;
  v_filtered_groups jsonb[];
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
      for v_attribute_name in
        select json.get_string(value)
        from jsonb_array_elements(json.get_array(v_group, 'attributes'))
      loop
        if in_attributes ? v_attribute_name then
          v_filtered_attributes := array_append(v_filtered_attributes, v_attribute_name);
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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

-- drop function data.get_attribute_value(integer, text);

create or replace function data.get_attribute_value(in_object_id integer, in_attribute_name text)
returns jsonb
volatile
as
$$
declare
  v_attribute_id integer := data.get_attribute_id(in_attribute_name);
  v_attribute_value jsonb;
begin
  assert in_object_id is not null;
  assert data.can_attribute_be_overridden(v_attribute_id) is false;

  select value
  into v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = v_attribute_id and
    value_object_id is null;

  return v_attribute_value;
end;
$$
language 'plpgsql';

-- drop function data.get_attribute_value(integer, text, integer);

create or replace function data.get_attribute_value(in_object_id integer, in_attribute_name text, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_attribute_id integer := data.get_attribute_id(in_attribute_name);
  v_priority_attribute_id integer := data.get_attribute_id('priority');
  v_attribute_value jsonb;
begin
  assert in_object_id is not null;
  assert in_actor_id is not null;
  assert data.can_attribute_be_overridden(v_attribute_id) is true;

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
    av.attribute_id = v_attribute_id and
    (
      av.value_object_id is null or
      oo.id is not null
    )
  order by json.get_integer_opt(pr.value, 0) desc
  limit 1;

  return v_attribute_value;
end;
$$
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

-- drop function data.get_next_list(integer, integer);

create or replace function data.get_next_list(in_client_id integer, in_object_id integer)
returns jsonb
volatile
as
$$
declare
  v_page_size integer := data.get_integer_param(page_size);
  v_actor_id integer;
  v_last_object_id integer;
  v_content integer[];
  v_content_length integer;
  v_client_subscription_id integer;
  v_object record;
  v_mini_card_function text;
  v_is_visible boolean;
  v_count integer := 0;
  v_has_more boolean := false;
  v_objects jsonb[];
begin
  assert in_object_id is not null;
  assert v_page_size > 0;

  select actor_id
  into v_actor_id
  from data.clients
  where id = in_client_id
  for update;

  assert v_actor_id is not null;

  v_content = json.get_integer_array(data.get_attribute_value(in_object_id, 'content'));
  assert intarray.uniq(intarray.sort(v_content)) = v_content;

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
      c.value id,
      c.num as index
    from (
      select
        row_number() over() as num,
        value
      from unnest(v_content) s(value)) c
    where c.value not in (
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
      using v_object.id, in_actor_id;
    end if;

    -- Проверяем видимость
    v_is_visible := json.get_boolean_opt(data.get_attribute_value(v_object.id, 'is_visible', in_actor_id), null);
    if v_is_visible is null then
      insert into data.client_subscription_objects(client_subscription_id, object_id, index, is_visible)
      values(v_client_subscription_id, v_object.id, v_object.index, false);

      continue;
    end if;

    v_objects := array_append(v_objects, json.get_object(data.get_object(v_object.id, in_actor_id, 'mini', in_object_id), 'object'));

    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('objects', to_jsonb(v_objects), 'has_more', v_has_more);
end;
$$
language 'plpgsql';

-- drop function data.get_object(integer, integer, data.card_type, integer);

create or replace function data.get_object(in_object_id integer, in_actor_id integer, in_card_type data.card_type, in_actions_object_id integer)
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
  v_actions_function_attribute_id integer :=
    data.get_attribute_id(case when in_object_id = in_actions_object_id then 'actions_function' else 'list_actions_function' end);
  v_actions_function text;
  v_actions jsonb;
  v_template jsonb := data.get_param('template');
  v_object jsonb;
  v_list jsonb;
begin
  assert in_object_id is not null;
  assert in_actor_id is not null;
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
        case when lag(av.attribute_id) over (partition by av.object_id, av.attribute_id order by json.get_integer_opt(pr.value, 0) desc) is null then true else false end as needed
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
        (
          av.value_object_id is null or
          oo.id is not null
        )
    ) attr
    join data.attributes a
      on a.id = attr.attribute_id
      and (a.card_type is null or a.card_type = in_card_type)
      and a.type != 'system'
      and attr.needed = true
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
  select json.get_string_opt(value, null)
  into v_actions_function
  from data.attribute_values
  where
    object_id = in_actions_object_id and
    attribute_id = v_actions_function_attribute_id and
    value_object_id is null;

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

  -- Отфильтровываем из шаблона лишнее
  v_template := data.filter_template(v_template, v_attributes, v_actions);

  v_object :=
    jsonb_build_object('id', data.get_object_code(in_object_id), 'attributes', coalesce(v_attributes, jsonb '{}'), 'actions', coalesce(v_actions, jsonb '{}'), 'template', v_template);

  if v_attributes ? 'content' then
    assert in_card_type = 'full';

    v_list := data.get_next_list(in_client_id, in_object_id);
    return jsonb_build_object('object', v_object, 'list', v_list);
  end if;

  return jsonb_build_object('object', v_object);
end;
$$
language 'plpgsql';

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
  where id = in_object_id;

  if v_object_code is null then
    raise exception 'Can''t find object %', in_object_id;
  end if;

  return v_object_code;
end;
$$
language 'plpgsql';

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
  where code = in_object_code;

  if v_object_id is null then
    raise exception 'Can''t find object "%"', in_object_code;
  end if;

  return v_object_id;
end;
$$
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
    'Функция, вызываемая перед получением действий объекта, string. Вызывается с параметрами (object_id, actor_id) и возвращает действия.',
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
  ('content', null, 'Массив идентификаторов объектов списка, integer[]', 'hidden', 'full', null, false),
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
    'Функция, вызываемая перед получением действий объекта списка, string. Вызывается с параметрами (object_id, list_object_id, actor_id) и возвращает действия.',
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
  ('temporary_object', null, 'Атрибут, наличие которого говорит о том, что открытый объект не нужно сохранять в истории', 'hidden', 'full', null, false),
  ('title', null, 'Заголовок, string', 'normal', null, null, true),
  ('type', null, 'Тип объекта, string', 'hidden', null, null, true);
end;
$$
language 'plpgsql';

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
language 'plpgsql';

-- drop function data.log(data.severity, text, integer);

create or replace function data.log(in_severity data.severity, in_message text, in_actor_id integer default null::integer)
returns void
volatile
as
$$
begin
  insert into data.log(severity, message, actor_id)
  values(in_severity, in_message, in_actor_id);
end;
$$
language 'plpgsql';

-- drop function data.objects_after_insert();

create or replace function data.objects_after_insert()
returns trigger
volatile
as
$$
begin
  insert into data.object_objects(parent_object_id, object_id)
  values(new.id, new.id);

  return null;
end;
$$
language 'plpgsql';

-- drop function data.remove_object_from_object(integer, integer);

create or replace function data.remove_object_from_object(in_object_id integer, in_parent_object_id integer)
returns void
volatile
as
$$
declare
  v_connection_id integer;
begin
  assert in_object_id is not null;
  assert in_parent_object_id is not null;

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

  delete from data.object_objects
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
    );
end;
$$
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

-- drop function json.get_bigint_array(json, text);

create or replace function json.get_bigint_array(in_json json, in_name text default null::text)
returns bigint[]
immutable
as
$$
declare
  v_array json := json.get_array(in_json, in_name);
  v_array_len integer := json_array_length(v_array);
  v_ret_val bigint[];
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
language 'plpgsql';

-- drop function json.get_bigint_array(jsonb, text);

create or replace function json.get_bigint_array(in_json jsonb, in_name text default null::text)
returns bigint[]
immutable
as
$$
declare
  v_array jsonb := json.get_array(in_json, in_name);
  v_array_len integer := jsonb_array_length(v_array);
  v_ret_val bigint[];
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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

-- drop function json.get_boolean_array(json, text);

create or replace function json.get_boolean_array(in_json json, in_name text default null::text)
returns boolean[]
immutable
as
$$
declare
  v_array json := json.get_array(in_json, in_name);
  v_array_len integer := json_array_length(v_array);
  v_ret_val boolean[];
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
language 'plpgsql';

-- drop function json.get_boolean_array(jsonb, text);

create or replace function json.get_boolean_array(in_json jsonb, in_name text default null::text)
returns boolean[]
immutable
as
$$
declare
  v_array jsonb := json.get_array(in_json, in_name);
  v_array_len integer := jsonb_array_length(v_array);
  v_ret_val boolean[];
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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

-- drop function json.get_integer_array(json, text);

create or replace function json.get_integer_array(in_json json, in_name text default null::text)
returns integer[]
immutable
as
$$
declare
  v_array json := json.get_array(in_json, in_name);
  v_array_len integer := json_array_length(v_array);
  v_ret_val integer[];
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
language 'plpgsql';

-- drop function json.get_integer_array(jsonb, text);

create or replace function json.get_integer_array(in_json jsonb, in_name text default null::text)
returns integer[]
immutable
as
$$
declare
  v_array jsonb := json.get_array(in_json, in_name);
  v_array_len integer := jsonb_array_length(v_array);
  v_ret_val integer[];
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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

-- drop function json.get_string_array(json, text);

create or replace function json.get_string_array(in_json json, in_name text default null::text)
returns text[]
immutable
as
$$
declare
  v_array json := json.get_array(in_json, in_name);
  v_array_len integer := json_array_length(v_array);
  v_ret_val text[];
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
language 'plpgsql';

-- drop function json.get_string_array(jsonb, text);

create or replace function json.get_string_array(in_json jsonb, in_name text default null::text)
returns text[]
immutable
as
$$
declare
  v_array jsonb := json.get_array(in_json, in_name);
  v_array_len integer := jsonb_array_length(v_array);
  v_ret_val text[];
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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
language 'plpgsql';

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
  v_description_attribute_id integer;
  v_description2_attribute_id integer;
  v_description3_attribute_id integer;
  v_description4_attribute_id integer;
  v_empty1_attribute_id integer;
  v_integer_attribute_id integer;
  v_float_attribute_id integer;
  v_integer2_attribute_id integer;
  v_float2_attribute_id integer;
  v_short_name_attribute_id integer;
  v_long_name_attribute_id integer;
  v_short_name_value_integer_attribute_id integer;
  v_long_name_value_description_integer_attribute_id integer;
  v_default_login_id integer;
  v_menu_id integer;
  v_notifications_id integer;
  v_test_id integer;
  v_not_found_object_id integer;
  v_test_num integer := 2;
begin
  insert into data.attributes(code, type, card_type, can_be_overridden)
  values('description', 'normal', 'full', true)
  returning id into v_description_attribute_id;

  insert into data.attributes(code, type, card_type, can_be_overridden)
  values('description2', 'normal', 'full', true)
  returning id into v_description2_attribute_id;

  insert into data.attributes(code, type, card_type, can_be_overridden)
  values('description3', 'normal', 'full', true)
  returning id into v_description3_attribute_id;

  insert into data.attributes(code, type, card_type, can_be_overridden)
  values('empty1', 'normal', 'full', true)
  returning id into v_empty1_attribute_id;

  insert into data.attributes(code, type, card_type, can_be_overridden)
  values('description4', 'normal', 'full', true)
  returning id into v_description4_attribute_id;

  insert into data.attributes(code, type, card_type, can_be_overridden)
  values('integer', 'normal', 'full', true)
  returning id into v_integer_attribute_id;

  insert into data.attributes(code, type, card_type, can_be_overridden)
  values('float', 'normal', 'full', true)
  returning id into v_float_attribute_id;

  insert into data.attributes(code, value_description_function, type, card_type, can_be_overridden)
  values('integer2', 'test_project.test_value_description_function', 'normal', 'full', true)
  returning id into v_integer2_attribute_id;

  insert into data.attributes(code, value_description_function, type, card_type, can_be_overridden)
  values('float2', 'test_project.test_value_description_function', 'normal', 'full', true)
  returning id into v_float2_attribute_id;

  insert into data.attributes(code, name, type, card_type, can_be_overridden)
  values('short_name', 'Атрибут 1', 'normal', 'full', true)
  returning id into v_short_name_attribute_id;

  insert into data.attributes(code, name, type, card_type, can_be_overridden)
  values('long_name', 'Атрибут с очень длинным именем, которое нельзя так просто обрезать — оно очень важно для понимания назначения значения, его смысла, глубинной сути, места во вселенной и связи со значениями других атрибутов', 'normal', 'full', true)
  returning id into v_long_name_attribute_id;

  insert into data.attributes(code, name, type, card_type, can_be_overridden)
  values('short_name_value_integer', 'Атрибут 3', 'normal', 'full', true)
  returning id into v_short_name_value_integer_attribute_id;

  insert into data.attributes(code, name, value_description_function, type, card_type, can_be_overridden)
  values('long_name_value_description_integer', 'Ещё один атрибут с длинным именем, которое почти наверняка не поместится в одну строку на современных телефонах', 'test_project.test_value_description_function', 'normal', 'full', true)
  returning id into v_long_name_value_description_integer_attribute_id;

  -- Создадим актора по умолчанию, который является первым тестом
  insert into data.objects(code) values('test1') returning id into v_test_id;

  -- Создадим объект для страницы 404
  insert into data.objects(code) values('not_found') returning id into v_not_found_object_id;

  -- Логин по умолчанию
  insert into data.logins(code) values('default_login') returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_test_id);

  insert into data.params(code, value, description) values
  ('default_login_id', to_jsonb(v_default_login_id), 'Идентификатор логина по умолчанию'),
  ('not_found_object_id', to_jsonb(v_not_found_object_id), 'Идентификатор объекта, отображаемого в случае, если актору недоступен какой-то объект (ну или он реально не существует)'),
  (
    'template',
    jsonb
    '{
      "groups": [
        {
          "attributes": ["description", "integer", "float", "integer2", "float2", "description2"]
        },
        {
          "attributes": ["description3"]
        },
        {
          "name": "Короткое имя группы",
          "attributes": ["empty1", "description4"]
        },
        {
          "name": "Тестовые данные",
          "attributes": ["short_name", "long_name", "short_name_value_integer", "long_name_value_description_integer"]
        }
      ]
    }',
    'Шаблон'
  );

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

  -- 404
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_not_found_object_id, v_type_attribute_id, jsonb '"not_found"'),
  (v_not_found_object_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_not_found_object_id, v_title_attribute_id, jsonb '"404"'),
  (v_not_found_object_id, v_subtitle_attribute_id, jsonb '"Not found"'),
  (v_not_found_object_id, v_description_attribute_id, jsonb '"Это не те дроиды, которых вы ищете."');

  -- Тесты
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

Проверка 1: Этот текст разбит на строки. В частности, новая строка начинается сразу после текста "Добрый день!".
Так, если клиент выводит текст в разметке HTML, то полученные от сервера символы перевода строки должны преобразовываться в теги <br>.

Проверка 2: Если клиент преобразует получаемый от сервера текст в какую-то разметку, то все полученные данные должны экранироваться.
Если клиент использует HTML, то он должен экранировать три символа: амперсанд, меньше и больше. Так, в предыдущем пункте должен быть текст br, окружённый символами "меньше" и "больше", а в тексте далее должен быть явно виден символ "амперсанд" и не должно быть символа "больше": &gt;.

Проверка 3: После запуска приложения пользователю не показывали какие-то диалоги.
Приложение само запросило с сервера список акторов, само выбрало в качестве активного первый (в конце концов, в большинстве случаев список будет состоять из одного пункта, а мы не хотим заставлять пользователя делать лишние действия) и само же открыло объект этого выбранного актора.

Проверка 4: Приложение выводит только заголовок, подзаголовок и атрибуты, присутствующие в шаблоне. В данном конкретном случае нигде не выведен тип объекта ("test").
Считаем, что приложение честно не выводит атрибуты, отсутствующие в шаблоне и не являющиеся заголовком или подзаголовком, и верим, что атрибут с кодом "type" не обрабатывается особым образом :)

Проверка 5: Ниже есть ссылка с именем "Продолжить", ведущая на следующий тест. Приложение по нажатию на эту ссылку должно перейти к следующему объекту.

[Продолжить](babcom:test' || v_test_num || ')')
  );

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

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Проверяем вывод нетекстовых атрибутов.

Проверка: Ниже выведены числа -42 и 0.0314159265 (именно так, а не в экспоненциальной записи!).')
  ),
  (v_test_id, v_integer_attribute_id, jsonb '-42'),
  (v_test_id, v_float_attribute_id, jsonb '0.0314159265'),
  (
    v_test_id,
    v_description2_attribute_id,
    to_jsonb(text
'[Продолжить](babcom:test' || v_test_num || ')')
  );

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Проверяем вывод описаний значений атрибутов.

Проверка: Ниже выведены строки "минус сорок два" и "π / 100".')
  ),
  (v_test_id, v_integer2_attribute_id, jsonb '-42'),
  (v_test_id, v_float2_attribute_id, jsonb '0.0314159265'),
  (
    v_test_id,
    v_description2_attribute_id,
    to_jsonb(text
'[Продолжить](babcom:test' || v_test_num || ')')
  );

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Проверяем вывод описаний значений атрибутов с форматированием.

Проверка: Ниже выведена жирная строка "один" и наклонная строка "два".')
  ),
  (v_test_id, v_integer2_attribute_id, jsonb '1'),
  (v_test_id, v_float2_attribute_id, jsonb '2'),
  (
    v_test_id,
    v_description2_attribute_id,
    to_jsonb(text
'[Продолжить](babcom:test' || v_test_num || ')')
  );

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Теперь мы проверяем, как обрабатывается несколько групп и несколько атрибутов в одной группе.')
  ),
  (
    v_test_id,
    v_description2_attribute_id,
    to_jsonb(text
'Проверка 1: Эта строка находится в новом атрибуте. Она должна быть отделена от предыдущей, причём желательно, чтобы это разделение было визуально отлично от обычного начала новой строки.')
  ),
  (
    v_test_id,
    v_description3_attribute_id,
    to_jsonb(text
'Проверка 2: Эта строка находится в новой группе. Должно быть явно видно, где закончилась предыдущая группа и началась новая.

[Продолжить](babcom:test' || v_test_num || ')')
  );

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_empty1_attribute_id, null),
  (
    v_test_id,
    v_description4_attribute_id,
    to_jsonb(text
'Проверим вывод пустых атрибутов и групп с именем.

Проверка 1: Перед этим атрибутом в шаблоне идёт другой атрибут, но у него нет значения, имени и описания значения. Такой атрибут просто не должен выводиться, т.е. текст "Проверим вывод..." должен быть в самом верху группы, никаких дополнительных пропусков быть не должно.

Проверка 2: У этой группы есть имя. Мы должны видеть текст "Короткое имя группы".

[Продолжить](babcom:test' || v_test_num || ')')
  );

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

Проверка 1: Ниже есть ещё одна группа с именем "Тестовые данные".
Проверка 2: Первый атрибут в группе имеет имя "Атрибут 1" и не имеет значения и описания значения.
Проверка 3: Второй атрибут имеет длинное имя, которое не влезает в одну строку, начинается с "Атрибут с очень" и не имеет значения и описания значения.
Проверка 4: Третий атрибут имеет имя "Атрибут 3" и значение "100".
Проверка 5: Четвёртый атрибут имеет имя, начинающееся с "Ещё один атрибут" и также не влезающее в одну строку. Атрибут имеет довольно длинное описание значения, начинающееся с "Lorem ipsum".
Проверка 6: Слово ipsum должно быть жирным.
Проверка 7: Все атрибуты идут именно в указанном порядке.

[Продолжить](babcom:test' || v_test_num || ')')
  ),
  (v_test_id, v_short_name_attribute_id, null),
  (v_test_id, v_long_name_attribute_id, null),
  (v_test_id, v_short_name_value_integer_attribute_id, jsonb '100'),
  (v_test_id, v_long_name_value_description_integer_attribute_id, jsonb '3');

  -- Тест N
  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'TEMPLATE

[Продолжить](babcom:test' || v_test_num || ')')
  );
end;
$$
language 'plpgsql';

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
  elsif in_value = jsonb '3' then
    return 'Lorem **ipsum** dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.';
  elsif in_value = jsonb '0.0314159265' then
    return 'π / 100';
  end if;

  assert false;
end;
$$
language 'plpgsql';

-- Creating tables

-- drop table data.actions;

create table data.actions(
  id integer not null generated always as identity,
  code text not null,
  function text not null,
  constraint actions_pk primary key(id),
  constraint actions_unique_code unique(code)
);

comment on column data.actions.function is 'Имя функции для выполнения действия. Функция вызывается с параметрами (request_id, actor_id, params, user_params).';

-- drop table data.attribute_values;

create table data.attribute_values(
  id integer not null generated always as identity,
  object_id integer not null,
  attribute_id integer not null,
  value_object_id integer,
  value jsonb,
  start_time timestamp with time zone not null default now(),
  start_reason text,
  start_actor_id integer,
  constraint attribute_values_override_check check((value_object_id is null) or data.can_attribute_be_overridden(attribute_id)),
  constraint attribute_values_pk primary key(id)
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
comment on column data.attributes.value_description_function is 'Имя функции для получения описания значения атрибута. Функция вызывается с параметрами (attribute_id, value, actor_id).';
comment on column data.attributes.can_be_overridden is 'Если false, то значение атрибута не может переопределяться для объектов';

-- drop table data.client_subscription_objects;

create table data.client_subscription_objects(
  id integer not null generated always as identity,
  client_subscription_id integer not null,
  object_id integer not null,
  index integer not null,
  is_visible boolean not null,
  constraint client_subscription_objects_index_check check(index > 0),
  constraint client_subscription_objects_pk primary key(id),
  constraint client_subscription_objects_unique_csi_i unique(client_subscription_id, index),
  constraint client_subscription_objects_unique_oi_csi unique(object_id, client_subscription_id)
);

-- drop table data.client_subscriptions;

create table data.client_subscriptions(
  id integer not null generated always as identity,
  client_id integer not null,
  object_id integer not null,
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
  constraint clients_pk primary key(id),
  constraint clients_unique_code unique(code)
);

-- drop table data.log;

create table data.log(
  id integer not null generated always as identity,
  severity data.severity not null,
  event_time timestamp with time zone not null default now(),
  message text not null,
  actor_id integer,
  constraint log_pk primary key(id)
);

-- drop table data.login_actors;

create table data.login_actors(
  id integer not null generated always as identity,
  login_id integer not null,
  actor_id integer not null,
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
  start_time timestamp with time zone not null default now(),
  constraint object_objects_intermediate_object_ids_check check(intarray.uniq(intarray.sort(intermediate_object_ids)) = intarray.sort(intermediate_object_ids)),
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
  code text not null default (pgcrypto.gen_random_uuid())::text,
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