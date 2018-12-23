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

-- Creating enums

-- drop type api_utils.output_message_type;

create type api_utils.output_message_type as enum(
  'actors',
  'object',
  'page',
  'show_object',
  'switch_actor');

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

-- drop function api.connect_client(text);

create or replace function api.connect_client(in_client_code text)
returns void
volatile
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

    perform data.log('info', format('Connected client with code "%"', in_client_code));
  end if;
end;
$$
language 'plpgsql';

-- drop function api.disconnect_all_clients();

create or replace function api.disconnect_all_clients()
returns void
volatile
as
$$
begin
  delete from data.notifications;

  update data.clients
  set is_connected = false;

  perform data.log('info', 'All clients were disconnected');
end;
$$
language 'plpgsql';

-- drop function api.disconnect_client(text);

create or replace function api.disconnect_client(in_client_code text)
returns void
volatile
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
  set is_connected = false
  where id = v_client_id;

  delete from data.notifications
  where client_id = v_client_id;

  perform data.log('info', format('Disconnected client with code "%"', in_client_code));
end;
$$
language 'plpgsql';

-- drop function api.get_notification(text);

create or replace function api.get_notification(in_notification_code text)
returns jsonb
volatile
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
    raise exception 'Can''t find attribute "%s"', in_attribute_code;
  end if;

  return v_attribute_id;
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
    raise exception 'Can''t find object %s', in_object_id;
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
    raise exception 'Can''t find object "%s"', in_object_code;
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

-- drop function data.is_system_attribute(integer);

create or replace function data.is_system_attribute(in_attribute_id integer)
returns boolean
stable
as
$$
declare
  v_ret_val boolean;
begin
  select type = 'SYSTEM'
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

-- Creating tables

-- drop table data.attribute_values;

create table data.attribute_values(
  id integer not null generated always as identity,
  object_id integer not null,
  attribute_id integer not null,
  value_object_id integer,
  value jsonb,
  start_time timestamp with time zone not null default now(),
  start_reason text,
  start_object_id integer,
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
  start_object_id integer,
  end_time timestamp with time zone not null,
  end_reason text,
  end_object_id integer,
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

-- drop table data.clients;

create table data.clients(
  id integer not null generated always as identity,
  code text not null,
  is_connected boolean not null,
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
  id integer not null,
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

alter table data.attribute_values add constraint attribute_values_fk_attribute
foreign key(attribute_id) references data.attributes(id);

alter table data.attribute_values add constraint attribute_values_fk_object
foreign key(object_id) references data.objects(id);

alter table data.attribute_values add constraint attribute_values_fk_start_object
foreign key(start_object_id) references data.objects(id);

alter table data.attribute_values add constraint attribute_values_fk_value_object
foreign key(value_object_id) references data.objects(id);

alter table data.attribute_values_journal add constraint attribute_values_journal_fk_attribute
foreign key(attribute_id) references data.attributes(id);

alter table data.attribute_values_journal add constraint attribute_values_journal_fk_end_object
foreign key(end_object_id) references data.objects(id);

alter table data.attribute_values_journal add constraint attribute_values_journal_fk_object
foreign key(object_id) references data.objects(id);

alter table data.attribute_values_journal add constraint attribute_values_journal_fk_start_object
foreign key(start_object_id) references data.objects(id);

alter table data.attribute_values_journal add constraint attribute_values_journal_fk_value_object
foreign key(value_object_id) references data.objects(id);

alter table data.clients add constraint clients_fk_objects
foreign key(actor_id) references data.objects(id);

alter table data.log add constraint log_fk_objects
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

