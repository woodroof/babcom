-- Cleanup
drop schema if exists "action_generators" cascade;
drop schema if exists "actions" cascade;
drop schema if exists "api" cascade;
drop schema if exists "api_utils" cascade;
drop schema if exists "attribute_value_change_functions" cascade;
drop schema if exists "attribute_value_description_functions" cascade;
drop schema if exists "attribute_value_fill_functions" cascade;
drop schema if exists "data" cascade;
drop schema if exists "deferred_functions" cascade;
drop schema if exists "json" cascade;
drop schema if exists "json_test" cascade;
drop schema if exists "test" cascade;
drop schema if exists "user_api" cascade;
drop schema if exists "utils" cascade;
drop schema if exists "utils_test" cascade;
drop schema if exists "intarray" cascade;
drop schema if exists "pgcrypto" cascade;
-- Schemas
create schema "action_generators";
create schema "actions";
create schema "api";
create schema "api_utils";
create schema "attribute_value_change_functions";
create schema "attribute_value_description_functions";
create schema "attribute_value_fill_functions";
create schema "data";
create schema "deferred_functions";
create schema "json";
create schema "json_test";
create schema "test";
create schema "user_api";
create schema "utils";
create schema "utils_test";
-- Extensions
create schema "intarray";
create extension "intarray" schema "intarray";
create schema "pgcrypto";
create extension "pgcrypto" schema "pgcrypto";
-- Privileges
grant usage on schema api to http;
-- Types
-- Type: api.result

-- DROP TYPE api.result;

CREATE TYPE api.result AS
   (code integer,
    data json);
-- Type: api_utils.objects_process_result

-- DROP TYPE api_utils.objects_process_result;

CREATE TYPE api_utils.objects_process_result AS
   (object_ids integer[],
    filled_attributes_ids integer[]);
-- Type: data.attribute_type

-- DROP TYPE data.attribute_type;

CREATE TYPE data.attribute_type AS ENUM
   ('SYSTEM',
    'INVISIBLE',
    'HIDDEN',
    'NORMAL');
-- Type: data.attribute_value_info

-- DROP TYPE data.attribute_value_info;

CREATE TYPE data.attribute_value_info AS
   (last_modified timestamp with time zone,
    value jsonb);
-- Type: data.object_info

-- DROP TYPE data.object_info;

CREATE TYPE data.object_info AS
   (object_id integer,
    object_code text,
    attribute_codes text[],
    attribute_names text[],
    attribute_values jsonb[],
    attribute_value_descriptions text[],
    attribute_types data.attribute_type[]);
-- Type: data.severity

-- DROP TYPE data.severity;

CREATE TYPE data.severity AS ENUM
   ('ERROR',
    'WARNING',
    'INFO');
-- Functions
-- Function: action_generators.generate_if_attribute(jsonb)

-- DROP FUNCTION action_generators.generate_if_attribute(jsonb);

CREATE OR REPLACE FUNCTION action_generators.generate_if_attribute(in_params jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_object_id integer := json.get_opt_integer(in_params, null, 'object_id');

  v_user_object_id integer;

  v_check_attribute_id integer;
  v_check_attribute_value jsonb;
  v_condition boolean;

  v_function text;
  v_params jsonb;
  v_ret_val jsonb;
begin
  if v_object_id is null then
    return null;
  end if;

  v_user_object_id := json.get_integer(in_params, 'user_object_id');
  v_check_attribute_id := data.get_attribute_id(json.get_string(in_params, 'attribute_code'));
  v_check_attribute_value := in_params->'attribute_value';

  select true
  into v_condition
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_check_attribute_id and
    value_object_id is null and
    value = v_check_attribute_value;

  if v_condition is null then
    return null;
  end if;

  v_function := json.get_string(in_params, 'function');
  v_params :=
    json.get_opt_object(in_params, jsonb '{}', 'params') ||
    jsonb_build_object(
      'user_object_id', v_user_object_id,
      'object_id', v_object_id);

  execute format('select action_generators.%s($1)', v_function)
  using v_params
  into v_ret_val;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: action_generators.generate_if_value_attribute(jsonb)

-- DROP FUNCTION action_generators.generate_if_value_attribute(jsonb);

CREATE OR REPLACE FUNCTION action_generators.generate_if_value_attribute(in_params jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_object_id integer := json.get_opt_integer(in_params, 'object_id');

  v_user_object_id integer;
  v_value_object_id integer;

  v_check_attribute_id integer;
  v_check_attribute_value jsonb;
  v_condition boolean;

  v_function text;
  v_params jsonb;
  v_ret_val jsonb;
begin
  if v_object_id is null then
    return null;
  end if;

  v_user_object_id := json.get_integer(in_params, 'user_object_id');
  v_value_object_id := json.get_integer(in_params, 'value_object_id');
  v_check_attribute_id := data.get_attribute_id(json.get_string(in_params, 'attribute_code'));
  v_check_attribute_value := in_params->'attribute_value';

  select true
  into v_condition
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_check_attribute_id and
    value_object_id = v_value_object_id and
    value = v_check_attribute_value;

  if v_condition is null then
    return null;
  end if;

  v_function := json.get_string(in_params, 'function');
  v_params :=
    json.get_opt_object(in_params, jsonb '{}', 'params') ||
    jsonb_build_object(
      'user_object_id', v_user_object_id,
      'object_id', v_object_id,
      'value_object_id', v_value_object_id);

  execute format('select action_generators.%s($1)', v_function)
  using v_params
  into v_ret_val;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
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
-- Function: api_utils.build_attributes(text[], text[], jsonb[], text[], data.attribute_type[])

-- DROP FUNCTION api_utils.build_attributes(text[], text[], jsonb[], text[], data.attribute_type[]);

CREATE OR REPLACE FUNCTION api_utils.build_attributes(
    in_attribute_codes text[],
    in_attribute_names text[],
    in_attribute_values jsonb[],
    in_attribute_value_descriptions text[],
    in_attribute_types data.attribute_type[])
  RETURNS jsonb AS
$BODY$
declare
  v_size integer := array_length(in_attribute_codes, 1);
  v_ret_val jsonb := '{}';
begin
  if v_size is not null then
    assert array_length(in_attribute_names, 1) = v_size;
    assert array_length(in_attribute_values, 1) = v_size;
    assert array_length(in_attribute_value_descriptions, 1) = v_size;
    assert array_length(in_attribute_types, 1) = v_size;

    for i in 1..v_size loop
      assert in_attribute_codes[i] is not null;
      assert in_attribute_types[i] != 'SYSTEM';

      v_ret_val := v_ret_val ||
        jsonb_build_object(
          in_attribute_codes[i],
          jsonb_build_object(
            'name', in_attribute_names[i],
            'value', in_attribute_values[i]) ||
          case when in_attribute_types[i] != 'NORMAL' then
            jsonb_build_object(
              'hidden', true)
          else
            jsonb '{}'
          end ||
          case when in_attribute_value_descriptions[i] is not null then
            jsonb_build_object(
              'value_description', in_attribute_value_descriptions[i])
          else
            jsonb '{}'
          end);
    end loop;
  end if;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: api_utils.create_bad_request_result(text)

-- DROP FUNCTION api_utils.create_bad_request_result(text);

CREATE OR REPLACE FUNCTION api_utils.create_bad_request_result(in_message text)
  RETURNS api.result AS
$BODY$
begin
  assert in_message is not null;

  return row(400, json_build_object('message', in_message));
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: api_utils.create_conflict_result(text)

-- DROP FUNCTION api_utils.create_conflict_result(text);

CREATE OR REPLACE FUNCTION api_utils.create_conflict_result(in_message text)
  RETURNS api.result AS
$BODY$
begin
  assert in_message is not null;

  return row(409, json_build_object('message', in_message));
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: api_utils.create_forbidden_result(text)

-- DROP FUNCTION api_utils.create_forbidden_result(text);

CREATE OR REPLACE FUNCTION api_utils.create_forbidden_result(in_message text)
  RETURNS api.result AS
$BODY$
begin
  assert in_message is not null;

  return row(403, json_build_object('message', in_message));
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: api_utils.create_internal_server_error_result(text)

-- DROP FUNCTION api_utils.create_internal_server_error_result(text);

CREATE OR REPLACE FUNCTION api_utils.create_internal_server_error_result(in_message text)
  RETURNS api.result AS
$BODY$
begin
  assert in_message is not null;

  return row(500, json_build_object('message', in_message));
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: api_utils.create_not_found_result(text)

-- DROP FUNCTION api_utils.create_not_found_result(text);

CREATE OR REPLACE FUNCTION api_utils.create_not_found_result(in_message text)
  RETURNS api.result AS
$BODY$
begin
  assert in_message is not null;

  return row(404, json_build_object('message', in_message));
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: api_utils.create_not_modified_result()

-- DROP FUNCTION api_utils.create_not_modified_result();

CREATE OR REPLACE FUNCTION api_utils.create_not_modified_result()
  RETURNS api.result AS
$BODY$
begin
  return row(304, null::json);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: api_utils.create_ok_result(json, text)

-- DROP FUNCTION api_utils.create_ok_result(json, text);

CREATE OR REPLACE FUNCTION api_utils.create_ok_result(
    in_data json,
    in_message text DEFAULT NULL::text)
  RETURNS api.result AS
$BODY$
begin
  if in_message is null then
    return row(200, json_build_object('data', in_data));
  end if;

  return row(200, json_build_object('data', in_data, 'message', in_message));
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: api_utils.get_filtered_object_ids(integer, text[], jsonb)

-- DROP FUNCTION api_utils.get_filtered_object_ids(integer, text[], jsonb);

CREATE OR REPLACE FUNCTION api_utils.get_filtered_object_ids(
    in_user_object_id integer,
    in_object_codes text[],
    in_params jsonb)
  RETURNS api_utils.objects_process_result AS
$BODY$
declare
  v_filters jsonb;

  v_system_is_visibile_attribute_id integer := data.get_attribute_id('system_is_visible');

  v_object_codes_to_remove text[];
  v_attribute_ids integer[];
  v_conditions text[];

  v_filtered_object_codes text[];
  v_filtered_object_ids integer[];
begin
  assert in_user_object_id is not null;
  assert in_object_codes is not null;
  assert in_params is not null;

  if in_params ? 'filters' then
    v_filters := json.get_object_array(in_params, 'filters');

    declare
      v_filter jsonb;
      v_code text;
      v_filters_len integer;
      v_type text;
      v_attribute_id integer;
      v_condition text;
    begin
      v_filters_len := jsonb_array_length(v_filters);

      for i in 0 .. v_filters_len - 1 loop
        v_filter := v_filters->i;
        v_type := json.get_string(v_filter, 'type');

        if v_type = 'code not in' then
          v_object_codes_to_remove := v_object_codes_to_remove || json.get_string_array(v_filter, 'data');
        elsif v_type = 'after' then
          v_code := json.get_string(v_filter, 'data');
          in_object_codes := utils.string_array_after(in_object_codes, v_code);
        else
          v_attribute_id :=
            data.get_attribute_id(
              json.get_string(v_filter, 'attribute_code'));

          if data.is_system_attribute(v_attribute_id) then
            raise invalid_parameter_value;
          end if;

          v_attribute_ids := v_attribute_ids || v_attribute_id;

          v_condition := 'exists(select 1 from data.attribute_values where object_id = o.id and attribute_id = ' || v_attribute_id || ' and ';

          case when v_type = 'mask' then
            v_condition := v_condition || 'json.get_if_string(value) like ''' || replace(json.get_string(v_filter, 'data'), '''', '''''') || ''')';
          when v_type = 'contains one of' then
            v_condition := v_condition || 'exists(select 1 from jsonb_array_elements(json.get_if_array(value)) where ''' || to_json(json.get_array(v_filter, 'data')) || '''::jsonb @> value))';
          else
            if jsonb_typeof(v_filter->'data') = 'string' then
              v_condition := v_condition || 'json.get_if_string(value) ' || api_utils.get_operation(v_type) || ' ''' || replace(json.get_string(v_filter, 'data'), '''', '''''') || ''')';
            else
              v_condition := v_condition || 'json.get_if_integer(value) ' || api_utils.get_operation(v_type) || ' ''' || json.get_integer(v_filter, 'data') || ''')';
            end if;
          end case;

          v_conditions := v_conditions || v_condition;
        end if;
      end loop;
    exception when invalid_parameter_value then
      perform utils.raise_invalid_input_param_value('Invalid filters');
    end;
  end if;

  if v_object_codes_to_remove is not null then
    declare
      v_object_code text;
      v_object_code_to_remove text;
    begin
      foreach v_object_code in array in_object_codes loop
        if v_object_code != any(v_object_codes_to_remove) then
          v_filtered_object_codes := v_filtered_object_codes || v_object_code;
        end if;
      end loop;
    end;
  else
    v_filtered_object_codes := in_object_codes;
  end if;

  select array_agg(id)
  into v_filtered_object_ids
  from (
    select id
    from data.objects
    where code = any(v_filtered_object_codes)
    order by utils.string_array_idx(v_filtered_object_codes, code)
  ) s;

  if v_filtered_object_ids is null then
    return null;
  end if;

  v_attribute_ids := v_attribute_ids || v_system_is_visibile_attribute_id;

  if v_attribute_ids is not null then
    perform data.fill_attribute_values(in_user_object_id, v_filtered_object_ids, v_attribute_ids);
  end if;

  declare
    v_query text;
    v_condition text;
  begin
    v_query :=
      'select array_agg(o.id) from data.objects o where o.id = any($1) ' ||
      'and exists(select 1 from data.attribute_values where object_id = o.id and attribute_id = $2 and json.get_if_boolean(value))';

    if v_conditions is not null then
      foreach v_condition in array v_conditions loop
        v_query := v_query || ' and ' || v_condition;
      end loop;
    end if;

    execute v_query
    using v_filtered_object_ids, v_system_is_visibile_attribute_id
    into v_filtered_object_ids;
  end;

  return row(v_filtered_object_ids, v_attribute_ids);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: api_utils.get_objects_infos(integer, integer[], integer[], boolean, boolean)

-- DROP FUNCTION api_utils.get_objects_infos(integer, integer[], integer[], boolean, boolean);

CREATE OR REPLACE FUNCTION api_utils.get_objects_infos(
    in_user_object_id integer,
    in_object_ids integer[],
    in_attribute_ids integer[],
    in_get_actions boolean,
    in_get_templates boolean)
  RETURNS jsonb AS
$BODY$
declare
  v_template jsonb := data.get_param('template');
  v_object_infos data.object_info[];
  v_object_info data.object_info;
  v_attributes jsonb;
  v_actions jsonb;
  v_object_template jsonb;
  v_ret_val jsonb := '[]';
begin
  assert in_user_object_id is not null;
  assert in_object_ids is not null;
  assert in_get_actions is not null;
  assert in_get_templates is not null;

  v_object_infos := data.get_object_infos(in_user_object_id, in_object_ids, in_attribute_ids, in_get_actions, in_get_templates);

  foreach v_object_info in array v_object_infos loop
    v_attributes :=
      api_utils.build_attributes(
        v_object_info.attribute_codes,
        v_object_info.attribute_names,
        v_object_info.attribute_values,
        v_object_info.attribute_value_descriptions,
        v_object_info.attribute_types);

    if in_get_actions then
      v_actions := data.get_object_actions(in_user_object_id, v_object_info.object_id);
    end if;

    v_ret_val :=
      v_ret_val || (
        jsonb_build_object(
          'code',
          v_object_info.object_code) ||
        case when v_attributes is not null then
          jsonb_build_object('attributes', v_attributes)
        else
          jsonb '{}'
        end ||
        case when (v_attributes is not null or v_actions is not null) and in_get_templates then
          jsonb_build_object('template', data.get_object_template(v_template, v_object_info.attribute_codes, v_actions))
        else
          jsonb '{}'
        end ||
        case when v_actions is not null then
          jsonb_build_object('actions', v_actions)
        else
          jsonb '{}'
        end);
  end loop;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: api_utils.get_object_codes_info_from_attribute(integer, jsonb)

-- DROP FUNCTION api_utils.get_object_codes_info_from_attribute(integer, jsonb);

CREATE OR REPLACE FUNCTION api_utils.get_object_codes_info_from_attribute(
    in_user_object_id integer,
    in_params jsonb)
  RETURNS text[] AS
$BODY$
declare
  v_object_code text := json.get_string(in_params, 'object_code');
  v_attribute_code text := json.get_string(in_params, 'attribute_code');

  v_object_id integer := data.get_object_id(v_object_code);
  v_attribute_id integer := data.get_attribute_id(v_attribute_code);
  v_system_is_visible_attribute_id integer := data.get_attribute_id('system_is_visible');

  v_attribute_value jsonb;
begin
  assert in_user_object_id is not null;

  if data.is_system_attribute(v_attribute_id) then
    perform utils.raise_invalid_input_param_value('Can''t find attribute "%s"', v_attribute_code);
  end if;

  perform data.fill_attribute_values(in_user_object_id, array[v_object_id], array[v_system_is_visible_attribute_id]);

  if not data.is_object_visible(in_user_object_id, v_object_id) then
    perform utils.raise_invalid_input_param_value('Can''t find object "%s"', v_object_code);
  end if;

  perform data.fill_attribute_values(in_user_object_id, array[v_object_id], array[v_attribute_id]);

  v_attribute_value := data.get_attribute_value(in_user_object_id, v_object_id, v_attribute_id);

  if v_attribute_value is null then
    perform utils.raise_invalid_input_param_value('Object "%s" has no attribute "%s"', v_object_code, v_attribute_code);
  end if;

  return json.get_string_array(v_attribute_value);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: api_utils.get_operation(text)

-- DROP FUNCTION api_utils.get_operation(text);

CREATE OR REPLACE FUNCTION api_utils.get_operation(in_operation_name text)
  RETURNS text AS
$BODY$
begin
  case when in_operation_name = 'lt' then
    return '<';
  when in_operation_name = 'le' then
    return '<=';
  when in_operation_name = 'gt' then
    return '>';
  when in_operation_name = 'ge' then
    return '>=';
  end case;

  perform utils.raise_invalid_input_param_value('Invalid operation "%s"', in_operation_name);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: api_utils.get_sorted_object_ids(integer, integer[], integer[], jsonb)

-- DROP FUNCTION api_utils.get_sorted_object_ids(integer, integer[], integer[], jsonb);

CREATE OR REPLACE FUNCTION api_utils.get_sorted_object_ids(
    in_user_object_id integer,
    in_object_ids integer[],
    in_filled_attributes_ids integer[],
    in_params jsonb)
  RETURNS api_utils.objects_process_result AS
$BODY$
declare
  v_sort_params jsonb;
  v_object_ids integer[];
  v_attribute_ids integer[];
begin
  assert in_user_object_id is not null;
  assert in_object_ids is not null;
  assert in_filled_attributes_ids is not null;
  assert in_params is not null;

  if not (in_params ? 'sort') then
    return row(in_object_ids, in_filled_attributes_ids);
  end if;

  v_sort_params := json.get_object_array(in_params, 'sort');

  declare
    v_sort_params_len integer;
    v_sort_param jsonb;
    v_type text;
    v_ordered_by_code boolean := false;
    v_attribute_code text;
    v_attribute_id integer;
    v_attributes text[];
    v_order_conditions text[];
    v_query text;
    v_attribute text;
    v_order_condition text;
  begin
    v_sort_params_len := jsonb_array_length(v_sort_params);

    for i in 0 .. v_sort_params_len - 1 loop
      v_sort_param := v_sort_params->i;
      v_type := json.get_string(v_sort_param, 'type');

      if v_type not in ('asc', 'desc') then
        raise invalid_parameter_value;
      end if;

      v_attribute_code := json.get_opt_string(v_sort_param, null, 'attribute_code');

      if v_attribute_code is null then
        v_attributes := v_attributes || ('utils.integer_array_idx($1, o.id) a' || i);
        v_order_conditions := v_order_conditions || ('a' || i || ' ' || v_type);
        v_ordered_by_code := true;
        exit;
      else
        v_attribute_id := data.get_attribute_id(v_attribute_code);

        if data.is_system_attribute(v_attribute_id) then
          raise invalid_parameter_value;
        end if;

        if v_attribute_id != any(in_filled_attributes_ids) then
          v_attribute_ids := v_attribute_ids || v_attribute_id;
        end if;

        v_attributes := v_attributes || ('data.get_attribute_value(' || in_user_object_id  || ', o.id, ' || v_attribute_id || ') a' || i);
        v_order_conditions := v_order_conditions || ('a' || i || ' ' || v_type);
      end if;
    end loop;

    if not v_ordered_by_code then
      v_attributes := v_attributes || ('utils.integer_array_idx($1, o.id) a' || v_sort_params_len);
      v_order_conditions := v_order_conditions || ('a' || v_sort_params_len || ' asc');
    end if;

    if v_attribute_ids is not null then
      perform data.fill_attribute_values(in_user_object_id, in_object_ids, v_attribute_ids);
    end if;

    v_query := 'select array_agg(o.id) from (select o.id';
    foreach v_attribute in array v_attributes loop
      v_query := v_query || ', ' || v_attribute;
    end loop;

    v_query := v_query || ' from data.objects o where o.id = any($1) order by ';
    foreach v_order_condition in array v_order_conditions loop
      v_query := v_query || v_order_condition || ', ';
    end loop;
    v_query := v_query || 'o.code asc) o';

    execute v_query
    using in_object_ids
    into v_object_ids;
  exception when invalid_parameter_value then
    perform utils.raise_invalid_input_param_value('Invalid sort params');
  end;

  return row(v_object_ids, in_filled_attributes_ids || v_attribute_ids);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: api_utils.get_user_object(integer, jsonb)

-- DROP FUNCTION api_utils.get_user_object(integer, jsonb);

CREATE OR REPLACE FUNCTION api_utils.get_user_object(
    in_login_id integer,
    in_params jsonb)
  RETURNS integer AS
$BODY$
declare
  v_user_object_code text := json.get_string(in_params, 'user_object_code');
  v_object_id integer;
begin
  select o.id
  into v_object_id
  from data.login_objects lo
  join data.objects o on
    lo.login_id = in_login_id and
    o.id = lo.object_id and
    o.code = v_user_object_code;

  return v_object_id;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: api_utils.limit_object_ids(integer[], jsonb)

-- DROP FUNCTION api_utils.limit_object_ids(integer[], jsonb);

CREATE OR REPLACE FUNCTION api_utils.limit_object_ids(
    in_object_ids integer[],
    in_params jsonb)
  RETURNS integer[] AS
$BODY$
declare
  v_limit integer;
  v_object_ids integer[];
begin
  assert in_object_ids is not null;
  assert in_params is not null;

  v_limit := json.get_opt_integer(in_params, null, 'limit');
  if v_limit <= 0 then
    perform utils.raise_invalid_input_param_value('Limit should be greater than zero');
  end if;

  if v_limit is not null then
    v_object_ids := intarray.subarray(in_object_ids, 1, v_limit);
  else
    v_object_ids := in_object_ids;
  end if;

  return v_object_ids;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: api_utils.run_deferred_functions()

-- DROP FUNCTION api_utils.run_deferred_functions();

CREATE OR REPLACE FUNCTION api_utils.run_deferred_functions()
  RETURNS void AS
$BODY$
begin
  -- TODO
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: attribute_value_change_functions.any_value_to_object(jsonb)

-- DROP FUNCTION attribute_value_change_functions.any_value_to_object(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_change_functions.any_value_to_object(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_value_object_id integer := json.get_opt_integer(in_params, null, 'value_object_id');
  v_old_value text := in_params->'old_value';
  v_new_value text := in_params->'new_value';
  v_object_code jsonb := json.get_string(in_params, 'object_code');
begin
  if v_value_object_id is not null then
    return;
  end if;

  if
    v_old_value is not null and
    v_new_value is null
  then
    perform data.remove_object_from_object(
      v_object_id,
      data.get_object_id(v_object_code));
  end if;

  if
    v_new_value is not null and
    v_old_value is null
  then
    perform data.add_object_to_object(
      v_object_id,
      data.get_object_id(v_object_code));
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: attribute_value_change_functions.boolean_value_to_attribute(jsonb)

-- DROP FUNCTION attribute_value_change_functions.boolean_value_to_attribute(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_change_functions.boolean_value_to_attribute(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_value_object_id integer := json.get_opt_integer(in_params, null, 'value_object_id');
  v_old_value boolean := json.get_opt_boolean(in_params, null, 'old_value');
  v_new_value boolean := json.get_opt_boolean(in_params, null, 'new_value');
  v_dest_object_code text := json.get_string(in_params, 'object_code');
  v_dest_attribute_code text := json.get_string(in_params, 'attribute_code');
  v_dest_object_id integer;
  v_dest_attribute_id integer;
  v_dest_attribute_value jsonb;
begin
  if v_value_object_id is not null then
    return;
  end if;

  if coalesce(v_old_value, false) = coalesce(v_new_value, false) then
    return;
  end if;

  v_dest_object_id := data.get_object_id(v_dest_object_code);
  v_dest_attribute_id := data.get_attribute_id(v_dest_attribute_code);

  v_dest_attribute_value :=
    json.get_opt_array(
      data.get_attribute_value_for_update(
        v_dest_object_id,
        v_dest_attribute_id,
        null));

  if v_old_value is not null and v_old_value then
    v_dest_attribute_value := json.get_array(v_dest_attribute_value);
    v_dest_attribute_value := v_dest_attribute_value - data.get_object_code(v_object_id);
  elsif v_new_value is not null and v_new_value then
    v_dest_attribute_value := jsonb_build_array(data.get_object_code(v_object_id)) || coalesce(v_dest_attribute_value, jsonb '[]');
  end if;

  perform data.set_attribute_value(v_dest_object_id, v_dest_attribute_id, null, v_dest_attribute_value, json.get_opt_integer(in_params, null, 'user_object_id'));
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: attribute_value_change_functions.boolean_value_to_object(jsonb)

-- DROP FUNCTION attribute_value_change_functions.boolean_value_to_object(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_change_functions.boolean_value_to_object(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_value_object_id integer := json.get_opt_integer(in_params, null, 'value_object_id');
  v_old_value boolean := json.get_opt_boolean(in_params, null, 'old_value');
  v_new_value boolean := json.get_opt_boolean(in_params, null, 'new_value');
  v_object_code text := json.get_string(in_params, 'object_code');
begin
  if v_value_object_id is not null then
    return;
  end if;

  if
    v_old_value is not null and
    v_old_value != coalesce(v_new_value, false)
  then
    perform data.remove_object_from_object(
      v_object_id,
      data.get_object_id(v_object_code));
  end if;

  if
    v_new_value is not null and
    v_new_value != coalesce(v_old_value, false)
  then
    perform data.add_object_to_object(
      v_object_id,
      data.get_object_id(v_object_code));
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: attribute_value_change_functions.boolean_value_to_value_attribute(jsonb)

-- DROP FUNCTION attribute_value_change_functions.boolean_value_to_value_attribute(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_change_functions.boolean_value_to_value_attribute(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_value_object_id integer := json.get_opt_integer(in_params, null, 'value_object_id');
  v_old_value boolean := json.get_opt_boolean(in_params, null, 'old_value');
  v_new_value boolean := json.get_opt_boolean(in_params, null, 'new_value');
  v_dest_object_code text := json.get_string(in_params, 'object_code');
  v_dest_attribute_code text := json.get_string(in_params, 'attribute_code');
  v_dest_object_id integer;
  v_dest_attribute_id integer;
  v_dest_attribute_value jsonb;
begin
  if coalesce(v_old_value, false) = coalesce(v_new_value, false) then
    return;
  end if;

  v_dest_object_id := data.get_object_id(v_dest_object_code);
  v_dest_attribute_id := data.get_attribute_id(v_dest_attribute_code);

  v_dest_attribute_value :=
    json.get_opt_array(
      data.get_attribute_value_for_update(
        v_dest_object_id,
        v_dest_attribute_id,
        v_value_object_id));

  if v_old_value is not null and v_old_value then
    v_dest_attribute_value := json.get_array(v_dest_attribute_value);
    v_dest_attribute_value := v_dest_attribute_value - data.get_object_code(v_object_id);
  elsif v_new_value is not null and v_new_value then
    v_dest_attribute_value := jsonb_build_array(data.get_object_code(v_object_id)) || coalesce(v_dest_attribute_value, jsonb '[]');
  end if;

  perform data.set_attribute_value(v_dest_object_id, v_dest_attribute_id, v_value_object_id, v_dest_attribute_value, json.get_opt_integer(in_params, null, 'user_object_id'));
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: attribute_value_change_functions.string_value_to_object(jsonb)

-- DROP FUNCTION attribute_value_change_functions.string_value_to_object(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_change_functions.string_value_to_object(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_value_object_id integer := json.get_opt_integer(in_params, null, 'value_object_id');
  v_old_value text := json.get_opt_string(in_params, null, 'old_value');
  v_new_value text := json.get_opt_string(in_params, null, 'new_value');
  v_value_to_code_map jsonb := json.get_object(in_params, 'params');
  v_old_object_code text;
  v_new_object_code text;
begin
  if v_value_object_id is not null then
    return;
  end if;

  if v_old_value is not null then
    v_old_object_code := json.get_opt_string(v_value_to_code_map, null, v_old_value);
  end if;
  if v_new_value is not null then
    v_new_object_code := json.get_opt_string(v_value_to_code_map, null, v_new_value);
  end if;

  if
    v_old_object_code is not null and
    (
      v_new_object_code is null or
      v_old_object_code != v_new_object_code
    )
  then
    perform data.remove_object_from_object(
      v_object_id,
      data.get_object_id(v_old_object_code));
  end if;

  if
    v_new_object_code is not null and
    (
      v_old_object_code is null or
      v_old_object_code != v_new_object_code
    )
  then
    perform data.add_object_to_object(
      v_object_id,
      data.get_object_id(v_new_object_code));
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: attribute_value_description_functions.code(integer, integer, jsonb)

-- DROP FUNCTION attribute_value_description_functions.code(integer, integer, jsonb);

CREATE OR REPLACE FUNCTION attribute_value_description_functions.code(
    in_user_object_id integer,
    in_attribute_id integer,
    in_value jsonb)
  RETURNS text AS
$BODY$
declare
  v_object_id integer :=
    data.get_object_id(
      json.get_string(in_value));
begin
  return
    coalesce(
      json.get_opt_string(
        data.get_attribute_value(in_user_object_id, v_object_id, in_attribute_id)),
      'Инкогнито');
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: attribute_value_description_functions.codes(integer, integer, jsonb)

-- DROP FUNCTION attribute_value_description_functions.codes(integer, integer, jsonb);

CREATE OR REPLACE FUNCTION attribute_value_description_functions.codes(
    in_user_object_id integer,
    in_attribute_id integer,
    in_value jsonb)
  RETURNS text AS
$BODY$
declare
  v_attribute_name_id integer := data.get_attribute_id('name');
  v_object_codes text[] := json.get_string_array(in_value);
  v_ret_val text;
begin
  select
    string_agg(
      coalesce(
        json.get_opt_string(
          data.get_attribute_value(in_user_object_id, o.id, v_attribute_name_id)),
        'Инкогнито'),
      ', ')
  into v_ret_val
  from data.objects
  where o.code = any(v_object_codes);

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: attribute_value_fill_functions.fill_object_attribute_if(jsonb)

-- DROP FUNCTION attribute_value_fill_functions.fill_object_attribute_if(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.fill_object_attribute_if(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_object_id integer := json.get_integer(in_params, 'object_id');

  v_check_attribute_id integer := data.get_attribute_id(json.get_string(in_params, 'attribute_code'));
  v_check_attribute_value jsonb := in_params->'attribute_value';
  v_condition boolean;

  v_function text;
  v_params jsonb;
begin
  select true
  into v_condition
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_check_attribute_id and
    value_object_id is null and
    value = v_check_attribute_value;

  if v_condition is null then
    return;
  end if;

  v_function := json.get_string(in_params, 'function');
  v_params :=
    json.get_opt_object(in_params, jsonb '{}', 'params') ||
    jsonb_build_object(
      'user_object_id', json.get_integer(in_params, 'user_object_id'),
      'object_id', v_object_id,
      'attribute_id', json.get_integer(in_params, 'attribute_id'));
  execute format('select attribute_value_fill_functions.%s($1)', v_function)
  using v_params;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: attribute_value_fill_functions.fill_user_object_attribute_if(jsonb)

-- DROP FUNCTION attribute_value_fill_functions.fill_user_object_attribute_if(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.fill_user_object_attribute_if(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');

  v_check_attribute_id integer := data.get_attribute_id(json.get_string(in_params, 'attribute_code'));
  v_check_attribute_value jsonb := in_params->'attribute_value';
  v_condition boolean;

  v_function text;
  v_params jsonb;
begin
  if v_user_object_id != v_object_id then
    return;
  end if;

  select true
  into v_condition
  from data.attribute_values
  where
    object_id = v_user_object_id and
    attribute_id = v_check_attribute_id and
    value_object_id is null and
    value = v_check_attribute_value;

  if v_condition is null then
    return;
  end if;

  v_function := json.get_string(in_params, 'function');
  v_params :=
    json.get_opt_object(in_params, jsonb '{}', 'params') ||
    jsonb_build_object(
      'user_object_id', v_user_object_id,
      'object_id', v_object_id,
      'attribute_id', json.get_integer(in_params, 'attribute_id'));
  execute format('select attribute_value_fill_functions.%s($1)', v_function)
  using v_params;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: data.add_object_to_login(integer, integer, integer, text)

-- DROP FUNCTION data.add_object_to_login(integer, integer, integer, text);

CREATE OR REPLACE FUNCTION data.add_object_to_login(
    in_object_id integer,
    in_login_id integer,
    in_user_object_id integer DEFAULT NULL::integer,
    in_reason text DEFAULT NULL::text)
  RETURNS void AS
$BODY$
declare
  v_exists boolean;
begin
  assert in_login_id is not null;
  assert in_object_id is not null;

  perform id
  from data.logins
  where id = in_login_id;

  select true
  into v_exists
  from data.login_objects
  where
    login_id = in_login_id and
    object_id = in_object_id;

  if v_exists is not null then
    raise exception 'Object % is already accessible for login %', in_object_id, in_login_id;
  end if;

  insert into data.login_objects(login_id, object_id, start_time, start_reason, start_object_id)
  values (in_login_id, in_object_id, now(), in_reason, in_user_object_id);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: data.add_object_to_object(integer, integer)

-- DROP FUNCTION data.add_object_to_object(integer, integer);

CREATE OR REPLACE FUNCTION data.add_object_to_object(
    in_object_id integer,
    in_parent_object_id integer)
  RETURNS void AS
$BODY$
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
    raise exception 'Attempt to add already existed connection from object % to object %!', in_object_id, in_parent_object_id;
  end if;

  select true
  into v_cycle
  from data.object_objects
  where
    parent_object_id = in_object_id and
    object_id = in_parent_object_id;

  if v_cycle is not null then
    raise exception 'Attempt to add object % to object %, cycle detected!', in_object_id, in_parent_object_id;
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: data.create_checksum(integer, text, text, jsonb)

-- DROP FUNCTION data.create_checksum(integer, text, text, jsonb);

CREATE OR REPLACE FUNCTION data.create_checksum(
    in_user_object_id integer,
    in_generator_code text,
    in_action_code text,
    in_params jsonb)
  RETURNS text AS
$BODY$
begin
  assert in_user_object_id is not null;
  assert in_generator_code is not null;
  assert in_action_code is not null;

  return encode(pgcrypto.digest(in_user_object_id::text || in_generator_code || in_action_code || coalesce(in_params::text, '{}'), 'sha256'), 'base64');
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: data.delete_attribute_value(integer, integer, integer, integer, text)

-- DROP FUNCTION data.delete_attribute_value(integer, integer, integer, integer, text);

CREATE OR REPLACE FUNCTION data.delete_attribute_value(
    in_object_id integer,
    in_attribute_id integer,
    in_value_object_id integer,
    in_user_object_id integer DEFAULT NULL::integer,
    in_reason text DEFAULT NULL::text)
  RETURNS void AS
$BODY$
declare
  v_attribute_value record;
  v_change_function_info record;
begin
  assert in_object_id is not null;
  assert in_attribute_id is not null;

  select id, value, start_time, start_reason, start_object_id
  into v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    (
      (
        value_object_id is null and
        in_value_object_id is null
      ) or
      value_object_id = in_value_object_id
    )
  for update;

  if v_attribute_value is null then
    raise exception 'Value not found (object_id: %, attribute_id: %, value_object_id: %)', in_object_id, in_attribute_id, in_value_object_id;
  end if;

  insert into data.attribute_values_journal(
    object_id,
    attribute_id,
    value_object_id,
    value,
    start_time,
    start_reason,
    start_object_id,
    end_time,
    end_reason,
    end_object_id)
  values (
    in_object_id,
    in_attribute_id,
    in_value_object_id,
    v_attribute_value.value,
    v_attribute_value.start_time,
    v_attribute_value.start_reason,
    v_attribute_value.start_object_id,
    now(),
    in_reason,
    in_user_object_id);

  delete from data.attribute_values
  where id = v_attribute_value.id;

  for v_change_function_info in
    select
      function,
      params
    from data.attribute_value_change_functions
    where attribute_id = in_attribute_id
  loop
    execute format('select attribute_value_change_functions.%s($1)', v_change_function_info.function)
    using
      coalesce(v_change_function_info.params, jsonb '{}') ||
      jsonb_build_object(
        'user_object_id', in_user_object_id,
        'object_id', in_object_id,
        'attribute_id', in_attribute_id,
        'value_object_id', in_value_object_id,
        'old_value', v_attribute_value.value,
        'new_value', null);
  end loop;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: data.delete_attribute_value_if_exists(integer, integer, integer, integer, text)

-- DROP FUNCTION data.delete_attribute_value_if_exists(integer, integer, integer, integer, text);

CREATE OR REPLACE FUNCTION data.delete_attribute_value_if_exists(
    in_object_id integer,
    in_attribute_id integer,
    in_value_object_id integer,
    in_user_object_id integer DEFAULT NULL::integer,
    in_reason text DEFAULT NULL::text)
  RETURNS void AS
$BODY$
declare
  v_attribute_value record;
  v_change_function_info record;
begin
  assert in_object_id is not null;
  assert in_attribute_id is not null;

  select id, value, start_time, start_reason, start_object_id
  into v_attribute_value
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    (
      (
        value_object_id is null and
        in_value_object_id is null
      ) or
      value_object_id = in_value_object_id
    )
  for update;

  if v_attribute_value is null then
    return;
  end if;

  insert into data.attribute_values_journal(
    object_id,
    attribute_id,
    value_object_id,
    value,
    start_time,
    start_reason,
    start_object_id,
    end_time,
    end_reason,
    end_object_id)
  values (
    in_object_id,
    in_attribute_id,
    in_value_object_id,
    v_attribute_value.value,
    v_attribute_value.start_time,
    v_attribute_value.start_reason,
    v_attribute_value.start_object_id,
    now(),
    in_reason,
    in_user_object_id);

  delete from data.attribute_values
  where id = v_attribute_value.id;

  for v_change_function_info in
    select
      function,
      params
    from data.attribute_value_change_functions
    where attribute_id = in_attribute_id
  loop
    execute format('select attribute_value_change_functions.%s($1)', v_change_function_info.function)
    using
      coalesce(v_change_function_info.params, jsonb '{}') ||
      jsonb_build_object(
        'user_object_id', in_user_object_id,
        'object_id', in_object_id,
        'attribute_id', in_attribute_id,
        'value_object_id', in_value_object_id,
        'old_value', v_attribute_value.value,
        'new_value', null);
  end loop;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: data.fill_actions_checksum(jsonb, integer, integer, text)

-- DROP FUNCTION data.fill_actions_checksum(jsonb, integer, integer, text);

CREATE OR REPLACE FUNCTION data.fill_actions_checksum(
    in_actions jsonb,
    in_user_object_id integer,
    in_generator_id integer,
    in_generator_code text)
  RETURNS jsonb AS
$BODY$
declare
  v_action record;
  v_ret_val jsonb := jsonb '{}';
begin
  assert in_actions is not null;
  assert in_user_object_id is not null;
  assert in_generator_id is not null;
  assert in_generator_code is not null;

  for v_action in
    select *
    from jsonb_each(in_actions)
  loop
    v_ret_val :=
      v_ret_val ||
      jsonb_build_object(
        v_action.key,
        v_action.value ||
        jsonb_build_object(
          'params',
          coalesce(json.get_opt_object(v_action.value, null, 'params'), jsonb '{}') ||
          jsonb_build_object(
            'generator',
            in_generator_id,
            'checksum',
            data.create_checksum(in_user_object_id, in_generator_code, json.get_string(v_action.value, 'code'), json.get_opt_object(v_action.value, null, 'params')))));
  end loop;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: data.fill_attribute_values(integer, integer[], integer[])

-- DROP FUNCTION data.fill_attribute_values(integer, integer[], integer[]);

CREATE OR REPLACE FUNCTION data.fill_attribute_values(
    in_user_object_id integer,
    in_object_ids integer[],
    in_attribute_ids integer[])
  RETURNS void AS
$BODY$
declare
  v_object_count integer;
  v_function_info record;
  v_object_id integer;
begin
  assert in_user_object_id is not null;
  assert in_object_ids is not null;
  assert in_attribute_ids is not null;

  in_object_ids := intarray.uniq(intarray.sort(in_object_ids));

  select count(1)
  into v_object_count
  from data.objects
  where id = any(in_object_ids);

  if v_object_count != array_length(in_object_ids, 1) then
    raise exception 'Can''t fill attributes for unknown object';
  end if;

  for v_function_info in
    select attribute_id, function, params
    from data.attribute_value_fill_functions
    where attribute_id = any(in_attribute_ids)
  loop
    foreach v_object_id in array in_object_ids loop
      assert v_object_id is not null;

      execute 'select attribute_value_fill_functions.' || v_function_info.function || '($1)'
      using
        coalesce(v_function_info.params, jsonb '{}') ||
        jsonb_build_object('user_object_id', in_user_object_id, 'object_id', v_object_id, 'attribute_id', v_function_info.attribute_id);
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: data.get_array_param(text)

-- DROP FUNCTION data.get_array_param(text);

CREATE OR REPLACE FUNCTION data.get_array_param(in_code text)
  RETURNS jsonb AS
$BODY$
begin
  assert in_code is not null;

  return
    json.get_array(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not an array', in_code;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: data.get_attribute_id(text)

-- DROP FUNCTION data.get_attribute_id(text);

CREATE OR REPLACE FUNCTION data.get_attribute_id(in_attribute_code text)
  RETURNS integer AS
$BODY$
declare
  v_attribute_id integer;
begin
  assert in_attribute_code is not null;

  select id
  into v_attribute_id
  from data.attributes
  where code = in_attribute_code;

  if v_attribute_id is null then
    perform utils.raise_invalid_input_param_value('Can''t find attribute "%s"', in_attribute_code);
  end if;

  return v_attribute_id;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: data.get_attribute_value(integer, integer, integer)

-- DROP FUNCTION data.get_attribute_value(integer, integer, integer);

CREATE OR REPLACE FUNCTION data.get_attribute_value(
    in_user_object_id integer,
    in_object_id integer,
    in_attribute_id integer)
  RETURNS jsonb AS
$BODY$
declare
  v_ret_val jsonb;
  v_system_priority_attr_id integer := data.get_attribute_id('system_priority');
begin
  assert in_user_object_id is not null;
  assert in_object_id is not null;
  assert in_attribute_id is not null;

  select av.value
  into v_ret_val
  from data.attribute_values av
  left join data.object_objects oo on
    av.value_object_id = oo.parent_object_id and
    oo.object_id = in_user_object_id
  left join data.attribute_values pr on
    pr.object_id = av.value_object_id and
    pr.attribute_id = v_system_priority_attr_id and
    pr.value_object_id is null
  where
    av.object_id = in_object_id and
    av.attribute_id = in_attribute_id and
    (
      av.value_object_id is null or
      oo.id is not null
    )
  order by json.get_opt_integer(pr.value, 0) desc
  limit 1;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: data.get_attribute_values_descriptions(integer, integer[], jsonb[], text[])

-- DROP FUNCTION data.get_attribute_values_descriptions(integer, integer[], jsonb[], text[]);

CREATE OR REPLACE FUNCTION data.get_attribute_values_descriptions(
    in_user_object_id integer,
    in_attribute_ids integer[],
    in_values jsonb[],
    in_functions text[])
  RETURNS text AS
$BODY$
declare
  v_ret_val text[];
  v_next_val text;
begin
  assert in_user_object_id is not null;

  if in_attribute_ids is null then
    assert in_values is null;
    assert in_functions is null;
  end if;

  assert array_length(in_attribute_ids, 1) = array_length(in_values, 1);
  assert array_length(in_attribute_ids, 1) = array_length(in_functions, 1);

  for i in 1..array_length(in_attribute_ids, 1) loop
    assert in_attribute_ids[i] is not null;

    if in_functions[i] is not null and in_values[i] is not null then
      execute 'select attribute_value_description_functions.' || in_functions[i] || '($1, $2, $3)'
      using in_user_object_id, in_attribute_ids[i], in_values[i]
      into v_next_val;

      v_ret_val := v_ret_val || v_next_val;
    else
      v_ret_val := v_ret_val || null::text;
    end if;
  end loop;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: data.get_attribute_value_for_update(integer, integer, integer)

-- DROP FUNCTION data.get_attribute_value_for_update(integer, integer, integer);

CREATE OR REPLACE FUNCTION data.get_attribute_value_for_update(
    in_object_id integer,
    in_attribute_id integer,
    in_value_object_id integer)
  RETURNS jsonb AS
$BODY$
declare
  v_ret_val jsonb;
begin
  select value
  into v_ret_val
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    (
      value_object_id = in_value_object_id or
      (
        value_object_id is null and
        in_value_object_id is null
      )
    )
  for update;

  if v_ret_val is null then
    perform id
    from data.objects
    where id = in_object_id
    for update;

    select value
    into v_ret_val
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      (
        value_object_id = in_value_object_id or
        (
          value_object_id is null and
          in_value_object_id is null
        )
      )
    for update;
  end if;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: data.get_bigint_param(text)

-- DROP FUNCTION data.get_bigint_param(text);

CREATE OR REPLACE FUNCTION data.get_bigint_param(in_code text)
  RETURNS bigint AS
$BODY$
begin
  assert in_code is not null;

  return
    json.get_bigint(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not a bigint', in_code;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: data.get_boolean_param(text)

-- DROP FUNCTION data.get_boolean_param(text);

CREATE OR REPLACE FUNCTION data.get_boolean_param(in_code text)
  RETURNS boolean AS
$BODY$
begin
  assert in_code is not null;

  return
    json.get_boolean(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not a boolean', in_code;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: data.get_integer_param(text)

-- DROP FUNCTION data.get_integer_param(text);

CREATE OR REPLACE FUNCTION data.get_integer_param(in_code text)
  RETURNS integer AS
$BODY$
begin
  assert in_code is not null;

  return
    json.get_integer(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not an integer', in_code;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: data.get_object_actions(integer, integer)

-- DROP FUNCTION data.get_object_actions(integer, integer);

CREATE OR REPLACE FUNCTION data.get_object_actions(
    in_user_object_id integer,
    in_object_id integer)
  RETURNS jsonb AS
$BODY$
declare
  v_generator_info record;
  v_base_params jsonb := jsonb_build_object('user_object_id', in_user_object_id, 'object_id', in_object_id);
  v_generator_actions jsonb;
  v_actions jsonb;
begin
  assert in_user_object_id is not null;

  for v_generator_info in
    select
      id,
      code,
      function,
      params
    from data.action_generators
  loop
    execute format('select action_generators.%s($1)', v_generator_info.function)
    using v_base_params || coalesce(v_generator_info.params, jsonb '{}')
    into v_generator_actions;

    if v_generator_actions is not null then
      v_generator_actions := data.fill_actions_checksum(v_generator_actions, in_user_object_id, v_generator_info.id, v_generator_info.code);
      v_actions := coalesce(v_actions, jsonb '{}') || v_generator_actions;
    end if;
  end loop;

  return v_actions;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: data.get_object_code(integer)

-- DROP FUNCTION data.get_object_code(integer);

CREATE OR REPLACE FUNCTION data.get_object_code(in_object_id integer)
  RETURNS text AS
$BODY$
declare
  v_object_code text;
begin
  assert in_object_id is not null;

  select code
  into v_object_code
  from data.objects
  where id = in_object_id;

  if v_object_code is null then
    perform utils.raise_invalid_input_param_value('Can''t find object "%s"', in_object_id);
  end if;

  return v_object_code;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: data.get_object_id(text)

-- DROP FUNCTION data.get_object_id(text);

CREATE OR REPLACE FUNCTION data.get_object_id(in_object_code text)
  RETURNS integer AS
$BODY$
declare
  v_object_id integer;
begin
  assert in_object_code is not null;

  select id
  into v_object_id
  from data.objects
  where code = in_object_code;

  if v_object_id is null then
    perform utils.raise_invalid_input_param_value('Can''t find object "%s"', in_object_code);
  end if;

  return v_object_id;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: data.get_object_infos(integer, integer[], integer[], boolean, boolean)

-- DROP FUNCTION data.get_object_infos(integer, integer[], integer[], boolean, boolean);

CREATE OR REPLACE FUNCTION data.get_object_infos(
    in_user_object_id integer,
    in_object_ids integer[],
    in_attribute_ids integer[],
    in_get_actions boolean,
    in_get_templates boolean)
  RETURNS data.object_info[] AS
$BODY$
declare
  v_system_priority_attr_id integer := data.get_attribute_id('system_priority');
  v_ret_val data.object_info[];
begin
  assert in_user_object_id is not null;
  assert in_object_ids is not null;
  assert in_get_actions is not null;
  assert in_get_templates is not null;

  select array_agg(value)
  into v_ret_val
  from
  (
    select row(o.id, o.code, oi.attribute_codes, oi.attribute_names, oi.attribute_values, data.get_attribute_values_descriptions(in_user_object_id, oi.attribute_ids, oi.attribute_values, oi.attribute_value_description_functions), oi.attribute_types)::data.object_info as value
    from data.objects o
    left join (
      select
        oi.object_id,
        array_agg(a.id) attribute_ids,
        array_agg(a.code) attribute_codes,
        array_agg(a.name) attribute_names,
        array_agg(oi.value) attribute_values,
        array_agg(a.type) attribute_types,
        array_agg(a.value_description_function) attribute_value_description_functions
      from (
        select
          object_id,
          attribute_id,
          value,
          rank() over (partition by object_id, attribute_id order by json.get_opt_integer(priority, 0) desc) as rank
        from (
          select
            av.object_id,
            av.attribute_id,
            av.value,
            pr.value priority
          from data.attribute_values av
          left join data.object_objects oo on
            av.value_object_id = oo.parent_object_id and
            oo.object_id = in_user_object_id
          left join data.attribute_values pr on
            pr.object_id = av.value_object_id and
            pr.attribute_id = v_system_priority_attr_id and
            pr.value_object_id is null
          where
            av.object_id = any(in_object_ids) and
            av.attribute_id = any(in_attribute_ids) and
            (
              av.value_object_id is null or
              oo.id is not null
            )
        ) oi
      ) oi
      join data.attributes a on
        a.id = oi.attribute_id and
        oi.rank = 1
      group by oi.object_id
    ) oi on
      o.id = oi.object_id
    join (
      select row_number() over() sort_order, id
      from (
        select unnest(in_object_ids) as id
      ) a
    ) a on
      a.id = o.id
    where o.id = any(in_object_ids)
    order by a.sort_order
  ) o;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: data.get_object_param(text)

-- DROP FUNCTION data.get_object_param(text);

CREATE OR REPLACE FUNCTION data.get_object_param(in_code text)
  RETURNS jsonb AS
$BODY$
begin
  assert in_code is not null;

  return
    json.get_object(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not an object', in_code;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: data.get_object_template(jsonb, text[], jsonb)

-- DROP FUNCTION data.get_object_template(jsonb, text[], jsonb);

CREATE OR REPLACE FUNCTION data.get_object_template(
    in_template jsonb,
    in_object_attribute_codes text[],
    in_object_actions jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_template_groups jsonb := json.get_object_array(in_template, 'groups');
  v_group jsonb;
  v_object_groups jsonb := '[]';
  v_object_action_codes text[];

  v_attributes text[];
  v_group_attributes text[];
  v_attribute text;

  v_actions text[];
  v_group_actions text[];
  v_action text;
begin
  assert in_object_attribute_codes is not null or in_object_actions is not null;

  for v_group in
    select * from jsonb_array_elements(v_template_groups)
  loop
    v_group_attributes := null;
    v_group_actions := null;

    if in_object_attribute_codes is not null then
      v_attributes := json.get_opt_string_array(v_group, null, 'attributes');
      if v_attributes is not null then
        foreach v_attribute in array v_attributes loop
          if v_attribute = any(in_object_attribute_codes) then
            v_group_attributes := v_group_attributes || array[v_attribute];
          end if;
        end loop;
      end if;
    end if;

    if in_object_actions is not null then
      select array_agg(value)
      into v_object_action_codes
      from jsonb_object_keys(in_object_actions) s(value);

      v_actions := json.get_opt_string_array(v_group, null, 'actions');
      if v_actions is not null then
        foreach v_action in array v_actions loop
          if v_action = any(v_object_action_codes) then
            v_group_actions := v_group_actions || array[v_action];
          end if;
        end loop;
      end if;
    end if;

    if v_group_attributes is not null or v_group_actions is not null then
      v_object_groups :=
        v_object_groups ||
        (
          case when v_group_attributes is not null then
            jsonb_build_object('attributes', v_group_attributes)
          else
            jsonb '{}'
          end ||
          case when v_group_actions is not null then
            jsonb_build_object('actions', v_group_actions)
          else
            jsonb '{}'
          end ||
          case when v_group ? 'name' then
            jsonb_build_object('name', json.get_string(v_group, 'name'))
          else
            jsonb '{}'
          end);
    end if;
  end loop;

  return jsonb_build_object('groups', v_object_groups);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: data.get_param(text)

-- DROP FUNCTION data.get_param(text);

CREATE OR REPLACE FUNCTION data.get_param(in_code text)
  RETURNS jsonb AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: data.get_string_param(text)

-- DROP FUNCTION data.get_string_param(text);

CREATE OR REPLACE FUNCTION data.get_string_param(in_code text)
  RETURNS text AS
$BODY$
begin
  assert in_code is not null;

  return
    json.get_string(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not a string', in_code;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: data.is_object_visible(integer, integer)

-- DROP FUNCTION data.is_object_visible(integer, integer);

CREATE OR REPLACE FUNCTION data.is_object_visible(
    in_user_object_id integer,
    in_object_id integer)
  RETURNS boolean AS
$BODY$
begin
  assert in_user_object_id is not null;
  assert in_object_id is not null;

  return json.get_boolean(
    data.get_attribute_value(
      in_user_object_id,
      in_object_id,
      data.get_attribute_id('system_is_visible')));
exception when invalid_parameter_value then
  return false;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: data.is_system_attribute(integer)

-- DROP FUNCTION data.is_system_attribute(integer);

CREATE OR REPLACE FUNCTION data.is_system_attribute(in_attribute_id integer)
  RETURNS boolean AS
$BODY$
declare
  v_ret_val boolean;
begin
  select type = 'SYSTEM'
  into v_ret_val
  from data.attributes
  where id = in_attribute_id;

  if v_ret_val is null then
    raise exception 'Attribute with id % not found', in_attribute_id;
  end if;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
-- Function: data.log(data.severity, text, text, integer)

-- DROP FUNCTION data.log(data.severity, text, text, integer);

CREATE OR REPLACE FUNCTION data.log(
    in_severity data.severity,
    in_message text,
    in_client text,
    in_login_id integer)
  RETURNS void AS
$BODY$
begin
  insert into data.log(severity, message, client, login_id) values(in_severity, in_message, in_client, in_login_id);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: data.objects_after_insert()

-- DROP FUNCTION data.objects_after_insert();

CREATE OR REPLACE FUNCTION data.objects_after_insert()
  RETURNS trigger AS
$BODY$
begin
  insert into data.object_objects(parent_object_id, object_id)
  values (new.id, new.id);

  return null;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: data.remove_object_from_login(integer, integer, integer, text)

-- DROP FUNCTION data.remove_object_from_login(integer, integer, integer, text);

CREATE OR REPLACE FUNCTION data.remove_object_from_login(
    in_object_id integer,
    in_login_id integer,
    in_user_object_id integer DEFAULT NULL::integer,
    in_reason text DEFAULT NULL::text)
  RETURNS void AS
$BODY$
declare
  v_login_object_info record;
begin
  assert in_login_id is not null;
  assert in_object_id is not null;

  select id, start_time, start_reason, start_object_id
  into v_login_object_info
  from data.login_objects
  where
    login_id = in_login_id and
    object_id = in_object_id
  for update;

  if v_login_object_info is null then
    raise exception 'Object % is not accessible for login %', in_object_id, in_login_id;
  end if;

  insert into data.login_objects_journal(login_id, object_id, start_time, start_reason, start_object_id, end_time, end_reason, end_object_id)
  values (
    in_login_id,
    in_object_id,
    v_login_object_info.start_time,
    v_login_object_info.start_reason,
    v_login_object_info.start_object_id,
    now(),
    in_reason,
    in_user_object_id);

  delete from data.login_objects
  where id = v_login_object_info.id;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: data.remove_object_from_object(integer, integer)

-- DROP FUNCTION data.remove_object_from_object(integer, integer);

CREATE OR REPLACE FUNCTION data.remove_object_from_object(
    in_object_id integer,
    in_parent_object_id integer)
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: data.set_attribute_value(integer, integer, integer, jsonb, integer, text)

-- DROP FUNCTION data.set_attribute_value(integer, integer, integer, jsonb, integer, text);

CREATE OR REPLACE FUNCTION data.set_attribute_value(
    in_object_id integer,
    in_attribute_id integer,
    in_value_object_id integer,
    in_value jsonb,
    in_user_object_id integer DEFAULT NULL::integer,
    in_reason text DEFAULT NULL::text)
  RETURNS void AS
$BODY$
declare
  v_attribute_value_info record;
  v_change_function_info record;
  v_inserted boolean := false;
begin
  assert in_object_id is not null;
  assert in_attribute_id is not null;

  select id, value, start_time, start_reason, start_object_id
  into v_attribute_value_info
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    (
      (
        value_object_id is null and
        in_value_object_id is null
      ) or
      value_object_id = in_value_object_id
    )
  for update;

  loop
    if v_inserted or not v_attribute_value_info is null then
      exit;
    end if;

    begin
      insert into data.attribute_values(
        object_id,
        attribute_id,
        value_object_id,
        value,
        start_time,
        start_reason,
        start_object_id)
      values (
        in_object_id,
        in_attribute_id,
        in_value_object_id,
        in_value,
        now(),
        in_reason,
        in_user_object_id);

      v_inserted := true;
    exception when unique_violation then
      select id, value, start_time, start_reason, start_object_id
      into v_attribute_value_info
      from data.attribute_values
      where
        object_id = in_object_id and
        attribute_id = in_attribute_id and
        (
          (
            value_object_id is null and
            in_value_object_id is null
          ) or
          value_object_id = in_value_object_id
        )
      for update;
    end;
  end loop;

  if not v_inserted then
    insert into data.attribute_values_journal(
      object_id,
      attribute_id,
      value_object_id,
      value,
      start_time,
      start_reason,
      start_object_id,
      end_time,
      end_reason,
      end_object_id)
    values (
      in_object_id,
      in_attribute_id,
      in_value_object_id,
      v_attribute_value_info.value,
      v_attribute_value_info.start_time,
      v_attribute_value_info.start_reason,
      v_attribute_value_info.start_object_id,
      now(),
      in_reason,
      in_user_object_id);

    update data.attribute_values
    set
      value = in_value,
      start_time = now(),
      start_reason = in_reason,
      start_object_id = in_user_object_id
    where id = v_attribute_value_info.id;
  end if;

  for v_change_function_info in
    select
      function,
      params
    from data.attribute_value_change_functions
    where attribute_id = in_attribute_id
  loop
    execute format('select attribute_value_change_functions.%s($1)', v_change_function_info.function)
    using
      coalesce(v_change_function_info.params, jsonb '{}') ||
      jsonb_build_object(
        'user_object_id', in_user_object_id,
        'object_id', in_object_id,
        'attribute_id', in_attribute_id,
        'value_object_id', in_value_object_id,
        'old_value', v_attribute_value_info.value,
        'new_value', in_value);
  end loop;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: data.set_attribute_value_if_changed(integer, integer, integer, jsonb, integer, text)

-- DROP FUNCTION data.set_attribute_value_if_changed(integer, integer, integer, jsonb, integer, text);

CREATE OR REPLACE FUNCTION data.set_attribute_value_if_changed(
    in_object_id integer,
    in_attribute_id integer,
    in_value_object_id integer,
    in_value jsonb,
    in_user_object_id integer DEFAULT NULL::integer,
    in_reason text DEFAULT NULL::text)
  RETURNS void AS
$BODY$
declare
  v_attribute_value_info record;
  v_change_function_info record;
  v_inserted boolean := false;
begin
  assert in_object_id is not null;
  assert in_attribute_id is not null;

  select id, value, start_time, start_reason, start_object_id
  into v_attribute_value_info
  from data.attribute_values
  where
    object_id = in_object_id and
    attribute_id = in_attribute_id and
    (
      (
        value_object_id is null and
        in_value_object_id is null
      ) or
      value_object_id = in_value_object_id
    )
  for update;

  loop
    if v_inserted or not v_attribute_value_info is null then
      exit;
    end if;

    begin
      insert into data.attribute_values(
        object_id,
        attribute_id,
        value_object_id,
        value,
        start_time,
        start_reason,
        start_object_id)
      values (
        in_object_id,
        in_attribute_id,
        in_value_object_id,
        in_value,
        now(),
        in_reason,
        in_user_object_id);

      v_inserted := true;
    exception when unique_violation then
      select id, value, start_time, start_reason, start_object_id
      into v_attribute_value_info
      from data.attribute_values
      where
        object_id = in_object_id and
        attribute_id = in_attribute_id and
        (
          (
            value_object_id is null and
            in_value_object_id is null
          ) or
          value_object_id = in_value_object_id
        )
      for update;
    end;
  end loop;

  if not v_inserted then
    if
      (v_attribute_value_info.value is null and in_value is null) or
      v_attribute_value_info.value = in_value
    then
      return;
    end if;

    insert into data.attribute_values_journal(
      object_id,
      attribute_id,
      value_object_id,
      value,
      start_time,
      start_reason,
      start_object_id,
      end_time,
      end_reason,
      end_object_id)
    values (
      in_object_id,
      in_attribute_id,
      in_value_object_id,
      v_attribute_value_info.value,
      v_attribute_value_info.start_time,
      v_attribute_value_info.start_reason,
      v_attribute_value_info.start_object_id,
      now(),
      in_reason,
      in_user_object_id);

    update data.attribute_values
    set
      value = in_value,
      start_time = now(),
      start_reason = in_reason,
      start_object_id = in_user_object_id
    where id = v_attribute_value_info.id;
  end if;

  for v_change_function_info in
    select
      function,
      params
    from data.attribute_value_change_functions
    where attribute_id = in_attribute_id
  loop
    execute format('select attribute_value_change_functions.%s($1)', v_change_function_info.function)
    using
      coalesce(v_change_function_info.params, jsonb '{}') ||
      jsonb_build_object(
        'user_object_id', in_user_object_id,
        'object_id', in_object_id,
        'attribute_id', in_attribute_id,
        'value_object_id', in_value_object_id,
        'old_value', v_attribute_value_info.value,
        'new_value', in_value);
  end loop;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: data.set_client_login(text, integer, integer, text)

-- DROP FUNCTION data.set_client_login(text, integer, integer, text);

CREATE OR REPLACE FUNCTION data.set_client_login(
    in_client text,
    in_login_id integer,
    in_user_object_id integer DEFAULT NULL::integer,
    in_reason text DEFAULT NULL::text)
  RETURNS void AS
$BODY$
declare
  v_client_login_info record;
begin
  assert in_client is not null;

  select id, login_id, start_time, start_reason, start_object_id
  into v_client_login_info
  from data.client_login
  where client = in_client
  for update;

  if
    (
      in_login_id is null and
      v_client_login_info is null
    ) or
    in_login_id = v_client_login_info.login_id
  then
    return;
  end if;

  loop
    if not v_client_login_info is null then
      exit;
    end if;

    begin
      insert into data.client_login(
        client,
        login_id,
        start_time,
        start_reason,
        start_object_id)
      values (
        in_client,
        in_login_id,
        clock_timestamp(),
        in_reason,
        in_user_object_id);

      return;
    exception when unique_violation then
      select id, login_id, start_time, start_reason, start_object_id
      into v_client_login_info
      from data.client_login
      where client = in_client
      for update;
    end;
  end loop;

  insert into data.client_login_journal(
    client,
    login_id,
    start_time,
    start_reason,
    start_object_id,
    end_time,
    end_reason,
    end_object_id)
  values (
    in_client,
    v_client_login_info.login_id,
    v_client_login_info.start_time,
    v_client_login_info.start_reason,
    v_client_login_info.start_object_id,
    clock_timestamp(),
    in_reason,
    in_user_object_id);

  if in_login_id is null then
    delete from data.client_login
    where id = v_client_login_info.id;
  else
    update data.client_login
    set
      login_id = in_login_id,
      start_time = clock_timestamp(),
      start_reason = in_reason,
      start_object_id = in_user_object_id
    where id = v_client_login_info.id;
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: json.get_array(json, text)

-- DROP FUNCTION json.get_array(json, text);

CREATE OR REPLACE FUNCTION json.get_array(
    in_json json,
    in_name text DEFAULT NULL::text)
  RETURNS json AS
$BODY$
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
      perform utils.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'array' then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not an array', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'array' then
    perform utils.raise_invalid_input_param_value('Json is not an array');
  end if;

  return v_param;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_array(jsonb, text)

-- DROP FUNCTION json.get_array(jsonb, text);

CREATE OR REPLACE FUNCTION json.get_array(
    in_json jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS jsonb AS
$BODY$
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
      perform utils.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'array' then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not an array', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'array' then
    perform utils.raise_invalid_input_param_value('Json is not an array');
  end if;

  return v_param;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_bigint(json, text)

-- DROP FUNCTION json.get_bigint(json, text);

CREATE OR REPLACE FUNCTION json.get_bigint(
    in_json json,
    in_name text DEFAULT NULL::text)
  RETURNS bigint AS
$BODY$
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
      perform utils.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'number' then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'number' then
    perform utils.raise_invalid_input_param_value('Json is not a number');
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a bigint', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not a bigint');
    end if;
  end;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_bigint(jsonb, text)

-- DROP FUNCTION json.get_bigint(jsonb, text);

CREATE OR REPLACE FUNCTION json.get_bigint(
    in_json jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS bigint AS
$BODY$
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
      perform utils.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'number' then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'number' then
    perform utils.raise_invalid_input_param_value('Json is not a number');
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a bigint', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not a bigint');
    end if;
  end;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_bigint_array(json, text)

-- DROP FUNCTION json.get_bigint_array(json, text);

CREATE OR REPLACE FUNCTION json.get_bigint_array(
    in_json json,
    in_name text DEFAULT NULL::text)
  RETURNS bigint[] AS
$BODY$
declare
  v_array json := json.get_array(in_json, in_name);
  v_array_len integer := json_array_length(v_array);
  v_ret_val bigint[];
begin
  if v_array_len < 1 then
    raise invalid_parameter_value;
  end if;

  for i in 0 .. v_array_len - 1 loop
    v_ret_val := array_append(v_ret_val, json.get_bigint(v_array->i));
  end loop;

  return v_ret_val;
exception when invalid_parameter_value then
  if in_name is not null then
    perform utils.raise_invalid_input_param_value('Attribute "%s" is not a bigint array', in_name);
  else
    perform utils.raise_invalid_input_param_value('Json is not a bigint array');
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_bigint_array(jsonb, text)

-- DROP FUNCTION json.get_bigint_array(jsonb, text);

CREATE OR REPLACE FUNCTION json.get_bigint_array(
    in_json jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS bigint[] AS
$BODY$
declare
  v_array jsonb := json.get_array(in_json, in_name);
  v_array_len integer := jsonb_array_length(v_array);
  v_ret_val bigint[];
begin
  if v_array_len < 1 then
    raise invalid_parameter_value;
  end if;

  for i in 0 .. v_array_len - 1 loop
    v_ret_val := array_append(v_ret_val, json.get_bigint(v_array->i));
  end loop;

  return v_ret_val;
exception when invalid_parameter_value then
  if in_name is not null then
    perform utils.raise_invalid_input_param_value('Attribute "%s" is not a bigint array', in_name);
  else
    perform utils.raise_invalid_input_param_value('Json is not a bigint array');
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_boolean(json, text)

-- DROP FUNCTION json.get_boolean(json, text);

CREATE OR REPLACE FUNCTION json.get_boolean(
    in_json json,
    in_name text DEFAULT NULL::text)
  RETURNS boolean AS
$BODY$
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
      perform utils.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'boolean' then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a boolean', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'boolean' then
    perform utils.raise_invalid_input_param_value('Json is not a boolean');
  end if;

  return v_param;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_boolean(jsonb, text)

-- DROP FUNCTION json.get_boolean(jsonb, text);

CREATE OR REPLACE FUNCTION json.get_boolean(
    in_json jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS boolean AS
$BODY$
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
      perform utils.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'boolean' then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a boolean', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'boolean' then
    perform utils.raise_invalid_input_param_value('Json is not a boolean');
  end if;

  return v_param;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_if_array(json, json, text)

-- DROP FUNCTION json.get_if_array(json, json, text);

CREATE OR REPLACE FUNCTION json.get_if_array(
    in_json json,
    in_default json DEFAULT NULL::json,
    in_name text DEFAULT NULL::text)
  RETURNS json AS
$BODY$
declare
  v_default_type text;
  v_param json;
begin
  v_default_type := json_typeof(in_default);

  if v_default_type is not null and v_default_type != 'array' then
    raise exception 'Default value "%" is not an array', in_default::text;
  end if;

  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  if json_typeof(v_param) = 'array' then
    return v_param;
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_if_array(jsonb, jsonb, text)

-- DROP FUNCTION json.get_if_array(jsonb, jsonb, text);

CREATE OR REPLACE FUNCTION json.get_if_array(
    in_json jsonb,
    in_default jsonb DEFAULT NULL::jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS jsonb AS
$BODY$
declare
  v_default_type text;
  v_param jsonb;
begin
  v_default_type := jsonb_typeof(in_default);

  if v_default_type is not null and v_default_type != 'array' then
    raise exception 'Default value "%" is not an array', in_default::text;
  end if;

  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  if jsonb_typeof(v_param) = 'array' then
    return v_param;
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_if_bigint(json, bigint, text)

-- DROP FUNCTION json.get_if_bigint(json, bigint, text);

CREATE OR REPLACE FUNCTION json.get_if_bigint(
    in_json json,
    in_default bigint DEFAULT NULL::bigint,
    in_name text DEFAULT NULL::text)
  RETURNS bigint AS
$BODY$
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

  if json_typeof(v_param) = 'number' then
    begin
      v_ret_val := v_param;
      return v_ret_val;
    exception when others then
    end;
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_if_bigint(jsonb, bigint, text)

-- DROP FUNCTION json.get_if_bigint(jsonb, bigint, text);

CREATE OR REPLACE FUNCTION json.get_if_bigint(
    in_json jsonb,
    in_default bigint DEFAULT NULL::bigint,
    in_name text DEFAULT NULL::text)
  RETURNS bigint AS
$BODY$
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

  if jsonb_typeof(v_param) = 'number' then
    begin
      v_ret_val := v_param;
      return v_ret_val;
    exception when others then
    end;
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_if_boolean(json, boolean, text)

-- DROP FUNCTION json.get_if_boolean(json, boolean, text);

CREATE OR REPLACE FUNCTION json.get_if_boolean(
    in_json json,
    in_default boolean DEFAULT NULL::boolean,
    in_name text DEFAULT NULL::text)
  RETURNS boolean AS
$BODY$
declare
  v_param json;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  if json_typeof(v_param) = 'boolean' then
    return v_param;
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_if_boolean(jsonb, boolean, text)

-- DROP FUNCTION json.get_if_boolean(jsonb, boolean, text);

CREATE OR REPLACE FUNCTION json.get_if_boolean(
    in_json jsonb,
    in_default boolean DEFAULT NULL::boolean,
    in_name text DEFAULT NULL::text)
  RETURNS boolean AS
$BODY$
declare
  v_param jsonb;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  if jsonb_typeof(v_param) = 'boolean' then
    return v_param;
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_if_integer(json, integer, text)

-- DROP FUNCTION json.get_if_integer(json, integer, text);

CREATE OR REPLACE FUNCTION json.get_if_integer(
    in_json json,
    in_default integer DEFAULT NULL::integer,
    in_name text DEFAULT NULL::text)
  RETURNS integer AS
$BODY$
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

  if json_typeof(v_param) = 'number' then
    begin
      v_ret_val := v_param;
      return v_ret_val;
    exception when others then
    end;
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_if_integer(jsonb, integer, text)

-- DROP FUNCTION json.get_if_integer(jsonb, integer, text);

CREATE OR REPLACE FUNCTION json.get_if_integer(
    in_json jsonb,
    in_default integer DEFAULT NULL::integer,
    in_name text DEFAULT NULL::text)
  RETURNS integer AS
$BODY$
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

  if jsonb_typeof(v_param) = 'number' then
    begin
      v_ret_val := v_param;
      return v_ret_val;
    exception when others then
    end;
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_if_object(json, json, text)

-- DROP FUNCTION json.get_if_object(json, json, text);

CREATE OR REPLACE FUNCTION json.get_if_object(
    in_json json,
    in_default json DEFAULT NULL::json,
    in_name text DEFAULT NULL::text)
  RETURNS json AS
$BODY$
declare
  v_default_type text;
  v_param json;
begin
  v_default_type := json_typeof(in_default);

  if v_default_type is not null and v_default_type != 'object' then
    raise exception 'Default value "%" is not an object', in_default::text;
  end if;

  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  if json_typeof(v_param) = 'object' then
    return v_param;
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_if_object(jsonb, jsonb, text)

-- DROP FUNCTION json.get_if_object(jsonb, jsonb, text);

CREATE OR REPLACE FUNCTION json.get_if_object(
    in_json jsonb,
    in_default jsonb DEFAULT NULL::jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS jsonb AS
$BODY$
declare
  v_default_type text;
  v_param jsonb;
begin
  v_default_type := jsonb_typeof(in_default);

  if v_default_type is not null and v_default_type != 'object' then
    raise exception 'Default value "%" is not an object', in_default::text;
  end if;

  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  if jsonb_typeof(v_param) = 'object' then
    return v_param;
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_if_string(json, text, text)

-- DROP FUNCTION json.get_if_string(json, text, text);

CREATE OR REPLACE FUNCTION json.get_if_string(
    in_json json,
    in_default text DEFAULT NULL::text,
    in_name text DEFAULT NULL::text)
  RETURNS text AS
$BODY$
declare
  v_param json;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  if json_typeof(v_param) = 'string' then
    return v_param#>>'{}';
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_if_string(jsonb, text, text)

-- DROP FUNCTION json.get_if_string(jsonb, text, text);

CREATE OR REPLACE FUNCTION json.get_if_string(
    in_json jsonb,
    in_default text DEFAULT NULL::text,
    in_name text DEFAULT NULL::text)
  RETURNS text AS
$BODY$
declare
  v_param jsonb;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  if jsonb_typeof(v_param) = 'string' then
    return v_param#>>'{}';
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_integer(json, text)

-- DROP FUNCTION json.get_integer(json, text);

CREATE OR REPLACE FUNCTION json.get_integer(
    in_json json,
    in_name text DEFAULT NULL::text)
  RETURNS integer AS
$BODY$
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
      perform utils.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'number' then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'number' then
    perform utils.raise_invalid_input_param_value('Json is not a number');
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not an integer', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not an integer');
    end if;
  end;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_integer(jsonb, text)

-- DROP FUNCTION json.get_integer(jsonb, text);

CREATE OR REPLACE FUNCTION json.get_integer(
    in_json jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS integer AS
$BODY$
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
      perform utils.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'number' then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'number' then
    perform utils.raise_invalid_input_param_value('Json is not a number');
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not an integer', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not an integer');
    end if;
  end;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_integer_array(json, text)

-- DROP FUNCTION json.get_integer_array(json, text);

CREATE OR REPLACE FUNCTION json.get_integer_array(
    in_json json,
    in_name text DEFAULT NULL::text)
  RETURNS integer[] AS
$BODY$
declare
  v_array json := json.get_array(in_json, in_name);
  v_array_len integer := json_array_length(v_array);
  v_ret_val integer[];
begin
  if v_array_len < 1 then
    raise invalid_parameter_value;
  end if;

  for i in 0 .. v_array_len - 1 loop
    v_ret_val := array_append(v_ret_val, json.get_integer(v_array->i));
  end loop;

  return v_ret_val;
exception when invalid_parameter_value then
  if in_name is not null then
    perform utils.raise_invalid_input_param_value('Attribute "%s" is not an integer array', in_name);
  else
    perform utils.raise_invalid_input_param_value('Json is not an integer array');
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_integer_array(jsonb, text)

-- DROP FUNCTION json.get_integer_array(jsonb, text);

CREATE OR REPLACE FUNCTION json.get_integer_array(
    in_json jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS integer[] AS
$BODY$
declare
  v_array jsonb := json.get_array(in_json, in_name);
  v_array_len integer := jsonb_array_length(v_array);
  v_ret_val integer[];
begin
  if v_array_len < 1 then
    raise invalid_parameter_value;
  end if;

  for i in 0 .. v_array_len - 1 loop
    v_ret_val := array_append(v_ret_val, json.get_integer(v_array->i));
  end loop;

  return v_ret_val;
exception when invalid_parameter_value then
  if in_name is not null then
    perform utils.raise_invalid_input_param_value('Attribute "%s" is not an integer array', in_name);
  else
    perform utils.raise_invalid_input_param_value('Json is not an integer array');
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_object(json, text)

-- DROP FUNCTION json.get_object(json, text);

CREATE OR REPLACE FUNCTION json.get_object(
    in_json json,
    in_name text DEFAULT NULL::text)
  RETURNS json AS
$BODY$
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
      perform utils.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'object' then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not an object', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'object' then
    perform utils.raise_invalid_input_param_value('Json is not an object');
  end if;

  return v_param;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_object(jsonb, text)

-- DROP FUNCTION json.get_object(jsonb, text);

CREATE OR REPLACE FUNCTION json.get_object(
    in_json jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS jsonb AS
$BODY$
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
      perform utils.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'object' then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not an object', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'object' then
    perform utils.raise_invalid_input_param_value('Json is not an object');
  end if;

  return v_param;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_object_array(json, text)

-- DROP FUNCTION json.get_object_array(json, text);

CREATE OR REPLACE FUNCTION json.get_object_array(
    in_json json,
    in_name text DEFAULT NULL::text)
  RETURNS json AS
$BODY$
declare
  v_array json := json.get_array(in_json, in_name);
  v_array_len integer := json_array_length(v_array);
begin
  if v_array_len < 1 then
    raise invalid_parameter_value;
  end if;

  for i in 0 .. v_array_len - 1 loop
    perform json.get_object(v_array->i);
  end loop;

  return v_array;
exception when invalid_parameter_value then
  if in_name is not null then
    perform utils.raise_invalid_input_param_value('Attribute "%s" is not an object array', in_name);
  else
    perform utils.raise_invalid_input_param_value('Json is not an object array');
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_object_array(jsonb, text)

-- DROP FUNCTION json.get_object_array(jsonb, text);

CREATE OR REPLACE FUNCTION json.get_object_array(
    in_json jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS jsonb AS
$BODY$
declare
  v_array jsonb := json.get_array(in_json, in_name);
  v_array_len integer := jsonb_array_length(v_array);
begin
  if v_array_len < 1 then
    raise invalid_parameter_value;
  end if;

  for i in 0 .. v_array_len - 1 loop
    perform json.get_object(v_array->i);
  end loop;

  return v_array;
exception when invalid_parameter_value then
  if in_name is not null then
    perform utils.raise_invalid_input_param_value('Attribute "%s" is not an object array', in_name);
  else
    perform utils.raise_invalid_input_param_value('Json is not an object array');
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_array(json, json, text)

-- DROP FUNCTION json.get_opt_array(json, json, text);

CREATE OR REPLACE FUNCTION json.get_opt_array(
    in_json json,
    in_default json DEFAULT NULL::json,
    in_name text DEFAULT NULL::text)
  RETURNS json AS
$BODY$
declare
  v_default_type text;
  v_param json;
  v_param_type text;
begin
  v_default_type := json_typeof(in_default);

  if v_default_type is not null and v_default_type != 'array' then
    raise exception 'Default value "%" is not an array', in_default::text;
  end if;

  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := json_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'array' then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not an array', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not an array');
    end if;
  end if;

  return v_param;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_array(jsonb, jsonb, text)

-- DROP FUNCTION json.get_opt_array(jsonb, jsonb, text);

CREATE OR REPLACE FUNCTION json.get_opt_array(
    in_json jsonb,
    in_default jsonb DEFAULT NULL::jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS jsonb AS
$BODY$
declare
  v_default_type text;
  v_param jsonb;
  v_param_type text;
begin
  v_default_type := jsonb_typeof(in_default);

  if v_default_type is not null and v_default_type != 'array' then
    raise exception 'Default value "%" is not an array', in_default::text;
  end if;

  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := jsonb_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'array' then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not an array', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not an array');
    end if;
  end if;

  return v_param;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_bigint(json, bigint, text)

-- DROP FUNCTION json.get_opt_bigint(json, bigint, text);

CREATE OR REPLACE FUNCTION json.get_opt_bigint(
    in_json json,
    in_default bigint DEFAULT NULL::bigint,
    in_name text DEFAULT NULL::text)
  RETURNS bigint AS
$BODY$
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

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'number' then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not a number');
    end if;
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a bigint', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not a bigint');
    end if;
  end;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_bigint(jsonb, bigint, text)

-- DROP FUNCTION json.get_opt_bigint(jsonb, bigint, text);

CREATE OR REPLACE FUNCTION json.get_opt_bigint(
    in_json jsonb,
    in_default bigint DEFAULT NULL::bigint,
    in_name text DEFAULT NULL::text)
  RETURNS bigint AS
$BODY$
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

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'number' then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not a number');
    end if;
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a bigint', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not a bigint');
    end if;
  end;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_bigint_array(json, bigint[], text)

-- DROP FUNCTION json.get_opt_bigint_array(json, bigint[], text);

CREATE OR REPLACE FUNCTION json.get_opt_bigint_array(
    in_json json,
    in_default bigint[] DEFAULT NULL::bigint[],
    in_name text DEFAULT NULL::text)
  RETURNS bigint[] AS
$BODY$
declare
  v_array json := json.get_opt_array(in_json, null, in_name);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_bigint_array(v_array);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_bigint_array(jsonb, bigint[], text)

-- DROP FUNCTION json.get_opt_bigint_array(jsonb, bigint[], text);

CREATE OR REPLACE FUNCTION json.get_opt_bigint_array(
    in_json jsonb,
    in_default bigint[] DEFAULT NULL::bigint[],
    in_name text DEFAULT NULL::text)
  RETURNS bigint[] AS
$BODY$
declare
  v_array jsonb := json.get_opt_array(in_json, null, in_name);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_bigint_array(v_array);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_boolean(json, boolean, text)

-- DROP FUNCTION json.get_opt_boolean(json, boolean, text);

CREATE OR REPLACE FUNCTION json.get_opt_boolean(
    in_json json,
    in_default boolean DEFAULT NULL::boolean,
    in_name text DEFAULT NULL::text)
  RETURNS boolean AS
$BODY$
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

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'boolean' then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a boolean', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not a boolean');
    end if;
  end if;

  return v_param;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_boolean(jsonb, boolean, text)

-- DROP FUNCTION json.get_opt_boolean(jsonb, boolean, text);

CREATE OR REPLACE FUNCTION json.get_opt_boolean(
    in_json jsonb,
    in_default boolean DEFAULT NULL::boolean,
    in_name text DEFAULT NULL::text)
  RETURNS boolean AS
$BODY$
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

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'boolean' then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a boolean', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not a boolean');
    end if;
  end if;

  return v_param;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_integer(json, integer, text)

-- DROP FUNCTION json.get_opt_integer(json, integer, text);

CREATE OR REPLACE FUNCTION json.get_opt_integer(
    in_json json,
    in_default integer DEFAULT NULL::integer,
    in_name text DEFAULT NULL::text)
  RETURNS integer AS
$BODY$
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

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'number' then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not a number');
    end if;
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not an integer', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not an integer');
    end if;
  end;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_integer(jsonb, integer, text)

-- DROP FUNCTION json.get_opt_integer(jsonb, integer, text);

CREATE OR REPLACE FUNCTION json.get_opt_integer(
    in_json jsonb,
    in_default integer DEFAULT NULL::integer,
    in_name text DEFAULT NULL::text)
  RETURNS integer AS
$BODY$
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

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'number' then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not a number');
    end if;
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not an integer', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not an integer');
    end if;
  end;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_integer_array(json, integer[], text)

-- DROP FUNCTION json.get_opt_integer_array(json, integer[], text);

CREATE OR REPLACE FUNCTION json.get_opt_integer_array(
    in_json json,
    in_default integer[] DEFAULT NULL::integer[],
    in_name text DEFAULT NULL::text)
  RETURNS integer[] AS
$BODY$
declare
  v_array json := json.get_opt_array(in_json, null, in_name);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_integer_array(v_array);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_integer_array(jsonb, integer[], text)

-- DROP FUNCTION json.get_opt_integer_array(jsonb, integer[], text);

CREATE OR REPLACE FUNCTION json.get_opt_integer_array(
    in_json jsonb,
    in_default integer[] DEFAULT NULL::integer[],
    in_name text DEFAULT NULL::text)
  RETURNS integer[] AS
$BODY$
declare
  v_array jsonb := json.get_opt_array(in_json, null, in_name);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_integer_array(v_array);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_object(json, json, text)

-- DROP FUNCTION json.get_opt_object(json, json, text);

CREATE OR REPLACE FUNCTION json.get_opt_object(
    in_json json,
    in_default json DEFAULT NULL::json,
    in_name text DEFAULT NULL::text)
  RETURNS json AS
$BODY$
declare
  v_default_type text;
  v_param json;
  v_param_type text;
begin
  v_default_type := json_typeof(in_default);

  if v_default_type is not null and v_default_type != 'object' then
    raise exception 'Default value "%" is not an object', in_default::text;
  end if;

  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := json_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'object' then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not an object', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not an object');
    end if;
  end if;

  return v_param;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_object(jsonb, jsonb, text)

-- DROP FUNCTION json.get_opt_object(jsonb, jsonb, text);

CREATE OR REPLACE FUNCTION json.get_opt_object(
    in_json jsonb,
    in_default jsonb DEFAULT NULL::jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS jsonb AS
$BODY$
declare
  v_default_type text;
  v_param jsonb;
  v_param_type text;
begin
  v_default_type := jsonb_typeof(in_default);

  if v_default_type is not null and v_default_type != 'object' then
    raise exception 'Default value "%" is not an object', in_default::text;
  end if;

  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := jsonb_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'object' then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not an object', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not an object');
    end if;
  end if;

  return v_param;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_object_array(json, json, text)

-- DROP FUNCTION json.get_opt_object_array(json, json, text);

CREATE OR REPLACE FUNCTION json.get_opt_object_array(
    in_json json,
    in_default json DEFAULT NULL::json,
    in_name text DEFAULT NULL::text)
  RETURNS json AS
$BODY$
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

  v_array := json.get_opt_array(in_json, null, in_name);
  if v_array is null then
    return in_default;
  end if;

  return json.get_object_array(v_array);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_object_array(jsonb, jsonb, text)

-- DROP FUNCTION json.get_opt_object_array(jsonb, jsonb, text);

CREATE OR REPLACE FUNCTION json.get_opt_object_array(
    in_json jsonb,
    in_default jsonb DEFAULT NULL::jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS jsonb AS
$BODY$
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

  v_array := json.get_opt_array(in_json, null, in_name);
  if v_array is null then
    return in_default;
  end if;

  return json.get_object_array(v_array);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_string(json, text, text)

-- DROP FUNCTION json.get_opt_string(json, text, text);

CREATE OR REPLACE FUNCTION json.get_opt_string(
    in_json json,
    in_default text DEFAULT NULL::text,
    in_name text DEFAULT NULL::text)
  RETURNS text AS
$BODY$
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

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'string' then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a string', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not a string');
    end if;
  end if;

  return v_param#>>'{}';
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_string(jsonb, text, text)

-- DROP FUNCTION json.get_opt_string(jsonb, text, text);

CREATE OR REPLACE FUNCTION json.get_opt_string(
    in_json jsonb,
    in_default text DEFAULT NULL::text,
    in_name text DEFAULT NULL::text)
  RETURNS text AS
$BODY$
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

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'string' then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a string', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not a string');
    end if;
  end if;

  return v_param#>>'{}';
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_string_array(json, text[], text)

-- DROP FUNCTION json.get_opt_string_array(json, text[], text);

CREATE OR REPLACE FUNCTION json.get_opt_string_array(
    in_json json,
    in_default text[] DEFAULT NULL::text[],
    in_name text DEFAULT NULL::text)
  RETURNS text[] AS
$BODY$
declare
  v_array json := json.get_opt_array(in_json, null, in_name);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_string_array(v_array);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_opt_string_array(jsonb, text[], text)

-- DROP FUNCTION json.get_opt_string_array(jsonb, text[], text);

CREATE OR REPLACE FUNCTION json.get_opt_string_array(
    in_json jsonb,
    in_default text[] DEFAULT NULL::text[],
    in_name text DEFAULT NULL::text)
  RETURNS text[] AS
$BODY$
declare
  v_array jsonb := json.get_opt_array(in_json, null, in_name);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_string_array(v_array);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_string(json, text)

-- DROP FUNCTION json.get_string(json, text);

CREATE OR REPLACE FUNCTION json.get_string(
    in_json json,
    in_name text DEFAULT NULL::text)
  RETURNS text AS
$BODY$
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
      perform utils.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'string' then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a string', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'string' then
    perform utils.raise_invalid_input_param_value('Json is not a string');
  end if;

  return v_param#>>'{}';
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_string(jsonb, text)

-- DROP FUNCTION json.get_string(jsonb, text);

CREATE OR REPLACE FUNCTION json.get_string(
    in_json jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS text AS
$BODY$
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
      perform utils.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'string' then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a string', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'string' then
    perform utils.raise_invalid_input_param_value('Json is not a string');
  end if;

  return v_param#>>'{}';
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_string_array(json, text)

-- DROP FUNCTION json.get_string_array(json, text);

CREATE OR REPLACE FUNCTION json.get_string_array(
    in_json json,
    in_name text DEFAULT NULL::text)
  RETURNS text[] AS
$BODY$
declare
  v_array json := json.get_array(in_json, in_name);
  v_array_len integer := json_array_length(v_array);
  v_ret_val text[];
begin
  if v_array_len < 1 then
    raise invalid_parameter_value;
  end if;

  for i in 0 .. v_array_len - 1 loop
    v_ret_val := array_append(v_ret_val, json.get_string(v_array->i));
  end loop;

  return v_ret_val;
exception when invalid_parameter_value then
  if in_name is not null then
    perform utils.raise_invalid_input_param_value('Attribute "%s" is not a string array', in_name);
  else
    perform utils.raise_invalid_input_param_value('Json is not a string array');
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json.get_string_array(jsonb, text)

-- DROP FUNCTION json.get_string_array(jsonb, text);

CREATE OR REPLACE FUNCTION json.get_string_array(
    in_json jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS text[] AS
$BODY$
declare
  v_array jsonb := json.get_array(in_json, in_name);
  v_array_len integer := jsonb_array_length(v_array);
  v_ret_val text[];
begin
  if v_array_len < 1 then
    raise invalid_parameter_value;
  end if;

  for i in 0 .. v_array_len - 1 loop
    v_ret_val := array_append(v_ret_val, json.get_string(v_array->i));
  end loop;

  return v_ret_val;
exception when invalid_parameter_value then
  if in_name is not null then
    perform utils.raise_invalid_input_param_value('Attribute "%s" is not a string array', in_name);
  else
    perform utils.raise_invalid_input_param_value('Json is not a string array');
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_opt_array_should_return_default_value_for_non_existing_key()

-- DROP FUNCTION json_test.get_opt_array_should_return_default_value_for_non_existing_key();

CREATE OR REPLACE FUNCTION json_test.get_opt_array_should_return_default_value_for_non_existing_key()
  RETURNS void AS
$BODY$
declare
  v_json text := '''{"key1": "value1", "key2": 2}''';
  v_json_type text;
  v_default_value text := '''[1, "2", {"key": 3}]''';
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    execute 'select test.assert_eq(' || v_default_value || '::' || v_json_type || ', json.get_opt_array(' || v_json || '::' || v_json_type || ', ' || v_default_value || '::' || v_json_type || ', ''key''))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_opt_array_should_return_default_value_for_null_json()

-- DROP FUNCTION json_test.get_opt_array_should_return_default_value_for_null_json();

CREATE OR REPLACE FUNCTION json_test.get_opt_array_should_return_default_value_for_null_json()
  RETURNS void AS
$BODY$
declare
  v_json_type text;
  v_default_value text := '''[1, "2", {"key": 3}]''';
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    execute 'select test.assert_eq(' || v_default_value || '::' || v_json_type || ', json.get_opt_array(null::' || v_json_type || ', ' || v_default_value || '::' || v_json_type || '))';
    execute 'select test.assert_eq(' || v_default_value || '::' || v_json_type || ', json.get_opt_array(null::' || v_json_type || ', ' || v_default_value || '::' || v_json_type || ', ''key''))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_opt_array_should_throw_for_non_array_default_value()

-- DROP FUNCTION json_test.get_opt_array_should_throw_for_non_array_default_value();

CREATE OR REPLACE FUNCTION json_test.get_opt_array_should_throw_for_non_array_default_value()
  RETURNS void AS
$BODY$
declare
  v_json text := '''{"key1": "value1", "key2": 2}''';
  v_json_type text;
  v_json_value text;
  v_default_value text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json_value in array array [v_json, 'null'] loop
      foreach v_default_value in array array ['5', '"qwe"', '{}'] loop
        perform test.assert_throw(
	  'select json.get_opt_array(' || v_json_value || '::' || v_json_type || ', ''' || v_default_value || '''::' || v_json_type || ')',
	  '%' || v_default_value || '% is not an array');
        perform test.assert_throw(
          'select json.get_opt_array(' || v_json_value || '::' || v_json_type || ', ''' || v_default_value || '''::' || v_json_type || ', ''key'')',
          '%' || v_default_value || '% is not an array');
      end loop;
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_opt_bigint_should_return_default_value_for_non_existing_key()

-- DROP FUNCTION json_test.get_opt_bigint_should_return_default_value_for_non_existing_key();

CREATE OR REPLACE FUNCTION json_test.get_opt_bigint_should_return_default_value_for_non_existing_key()
  RETURNS void AS
$BODY$
declare
  v_json text := '''{"key1": "value1", "key2": 2}''';
  v_json_type text;
  v_default_value text := utils.random_bigint(-5, 5)::text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    execute 'select test.assert_eq(' || v_default_value || ', json.get_opt_bigint(' || v_json || '::' || v_json_type || ', ' || v_default_value || ', ''key''))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_opt_bigint_should_return_default_value_for_null_json()

-- DROP FUNCTION json_test.get_opt_bigint_should_return_default_value_for_null_json();

CREATE OR REPLACE FUNCTION json_test.get_opt_bigint_should_return_default_value_for_null_json()
  RETURNS void AS
$BODY$
declare
  v_json_type text;
  v_default_value text := utils.random_bigint(-5, 5)::text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    execute 'select test.assert_eq(' || v_default_value || ', json.get_opt_bigint(null::' || v_json_type || ', ' || v_default_value || '))';
    execute 'select test.assert_eq(' || v_default_value || ', json.get_opt_bigint(null::' || v_json_type || ', ' || v_default_value || ', ''key''))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_opt_boolean_should_return_false_for_ne_key_and_false_dv()

-- DROP FUNCTION json_test.get_opt_boolean_should_return_false_for_ne_key_and_false_dv();

CREATE OR REPLACE FUNCTION json_test.get_opt_boolean_should_return_false_for_ne_key_and_false_dv()
  RETURNS void AS
$BODY$
declare
  v_json text := '''{"key1": "value1", "key2": 2}''';
  v_json_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    execute 'select test.assert_false(json.get_opt_boolean(' || v_json || '::' || v_json_type || ', false, ''key''))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_opt_boolean_should_return_false_for_null_json_and_false_dv()

-- DROP FUNCTION json_test.get_opt_boolean_should_return_false_for_null_json_and_false_dv();

CREATE OR REPLACE FUNCTION json_test.get_opt_boolean_should_return_false_for_null_json_and_false_dv()
  RETURNS void AS
$BODY$
declare
  v_json_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    execute 'select test.assert_false(json.get_opt_boolean(null::' || v_json_type || ', false))';
    execute 'select test.assert_false(json.get_opt_boolean(null::' || v_json_type || ', false, ''key''))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_opt_boolean_should_return_true_for_ne_key_and_true_dv()

-- DROP FUNCTION json_test.get_opt_boolean_should_return_true_for_ne_key_and_true_dv();

CREATE OR REPLACE FUNCTION json_test.get_opt_boolean_should_return_true_for_ne_key_and_true_dv()
  RETURNS void AS
$BODY$
declare
  v_json text := '''{"key1": "value1", "key2": 2}''';
  v_json_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    execute 'select test.assert_true(json.get_opt_boolean(' || v_json || '::' || v_json_type || ', true, ''key''))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_opt_boolean_should_return_true_for_null_json_and_true_dv()

-- DROP FUNCTION json_test.get_opt_boolean_should_return_true_for_null_json_and_true_dv();

CREATE OR REPLACE FUNCTION json_test.get_opt_boolean_should_return_true_for_null_json_and_true_dv()
  RETURNS void AS
$BODY$
declare
  v_json_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    execute 'select test.assert_true(json.get_opt_boolean(null::' || v_json_type || ', true))';
    execute 'select test.assert_true(json.get_opt_boolean(null::' || v_json_type || ', true, ''key''))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_opt_integer_should_return_default_value_for_ne_key()

-- DROP FUNCTION json_test.get_opt_integer_should_return_default_value_for_ne_key();

CREATE OR REPLACE FUNCTION json_test.get_opt_integer_should_return_default_value_for_ne_key()
  RETURNS void AS
$BODY$
declare
  v_json text := '''{"key1": "value1", "key2": 2}''';
  v_json_type text;
  v_default_value text := utils.random_integer(-5, 5)::text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    execute 'select test.assert_eq(' || v_default_value || ', json.get_opt_integer(' || v_json || '::' || v_json_type || ', ' || v_default_value || ', ''key''))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_opt_integer_should_return_default_value_for_null_json()

-- DROP FUNCTION json_test.get_opt_integer_should_return_default_value_for_null_json();

CREATE OR REPLACE FUNCTION json_test.get_opt_integer_should_return_default_value_for_null_json()
  RETURNS void AS
$BODY$
declare
  v_json_type text;
  v_default_value text := utils.random_integer(-5, 5)::text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    execute 'select test.assert_eq(' || v_default_value || ', json.get_opt_integer(null::' || v_json_type || ', ' || v_default_value || '))';
    execute 'select test.assert_eq(' || v_default_value || ', json.get_opt_integer(null::' || v_json_type || ', ' || v_default_value || ', ''key''))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_opt_object_should_return_default_value_for_non_existing_key()

-- DROP FUNCTION json_test.get_opt_object_should_return_default_value_for_non_existing_key();

CREATE OR REPLACE FUNCTION json_test.get_opt_object_should_return_default_value_for_non_existing_key()
  RETURNS void AS
$BODY$
declare
  v_json text := '''{"key1": "value1", "key2": 2}''';
  v_json_type text;
  v_default_value text := '''{"key1": "value1", "key2": 2}''';
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    execute 'select test.assert_eq(' || v_default_value || '::' || v_json_type || ', json.get_opt_object(' || v_json || '::' || v_json_type || ', ' || v_default_value || '::' || v_json_type || ', ''key''))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_opt_object_should_return_default_value_for_null_json()

-- DROP FUNCTION json_test.get_opt_object_should_return_default_value_for_null_json();

CREATE OR REPLACE FUNCTION json_test.get_opt_object_should_return_default_value_for_null_json()
  RETURNS void AS
$BODY$
declare
  v_json_type text;
  v_default_value text := '''{"key1": "value1", "key2": 2}''';
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    execute 'select test.assert_eq(' || v_default_value || '::' || v_json_type || ', json.get_opt_object(null::' || v_json_type || ', ' || v_default_value || '::' || v_json_type || '))';
    execute 'select test.assert_eq(' || v_default_value || '::' || v_json_type || ', json.get_opt_object(null::' || v_json_type || ', ' || v_default_value || '::' || v_json_type || ', ''key''))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_opt_object_should_throw_for_non_object_default_value()

-- DROP FUNCTION json_test.get_opt_object_should_throw_for_non_object_default_value();

CREATE OR REPLACE FUNCTION json_test.get_opt_object_should_throw_for_non_object_default_value()
  RETURNS void AS
$BODY$
declare
  v_json text := '''{"key1": "value1", "key2": 2}''';
  v_json_type text;
  v_json_value text;
  v_default_value text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json_value in array array [v_json, 'null'] loop
      foreach v_default_value in array array ['5', '"qwe"', '[]'] loop
        perform test.assert_throw(
          'select json.get_opt_object(' || v_json_value || '::' || v_json_type || ', ''' || v_default_value || '''::' || v_json_type || ')',
          '%' || v_default_value || '% is not an object');
        perform test.assert_throw(
          'select json.get_opt_object(' || v_json_value || '::' || v_json_type || ', ''' || v_default_value || '''::' || v_json_type || ', ''key'')',
          '%' || v_default_value || '% is not an object');
      end loop;
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_opt_string_should_return_default_value_for_non_existing_key()

-- DROP FUNCTION json_test.get_opt_string_should_return_default_value_for_non_existing_key();

CREATE OR REPLACE FUNCTION json_test.get_opt_string_should_return_default_value_for_non_existing_key()
  RETURNS void AS
$BODY$
declare
  v_json text := '''{"key1": "value1", "key2": 2}''';
  v_json_type text;
  v_default_value text := '''123qwe''';
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    execute 'select test.assert_eq(' || v_default_value || ', json.get_opt_string(' || v_json || '::' || v_json_type || ', ' || v_default_value || ', ''key''))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_opt_string_should_return_default_value_for_null_json()

-- DROP FUNCTION json_test.get_opt_string_should_return_default_value_for_null_json();

CREATE OR REPLACE FUNCTION json_test.get_opt_string_should_return_default_value_for_null_json()
  RETURNS void AS
$BODY$
declare
  v_json_type text;
  v_default_value text := '''123qwe''';
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    execute 'select test.assert_eq(' || v_default_value || ', json.get_opt_string(null::' || v_json_type || ', ' || v_default_value || '))';
    execute 'select test.assert_eq(' || v_default_value || ', json.get_opt_string(null::' || v_json_type || ', ' || v_default_value || ', ''key''))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_array_should_throw_for_invalid_json_type()

-- DROP FUNCTION json_test.get_x_array_should_throw_for_invalid_json_type();

CREATE OR REPLACE FUNCTION json_test.get_x_array_should_throw_for_invalid_json_type()
  RETURNS void AS
$BODY$
declare
  v_json text;
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''5''', '''"qwe"''', '''{}''', '''true'''] loop
      perform test.assert_throw(
        'select json.get_array(' || v_json || '::' || v_json_type || ')',
        'Json is not an array');
      perform test.assert_throw(
        'select json.get_opt_array(' || v_json || '::' || v_json_type || ', ''[]''::' || v_json_type || ')',
        'Json is not an array');
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_array_should_throw_for_invalid_param_type()

-- DROP FUNCTION json_test.get_x_array_should_throw_for_invalid_param_type();

CREATE OR REPLACE FUNCTION json_test.get_x_array_should_throw_for_invalid_param_type()
  RETURNS void AS
$BODY$
declare
  v_json text;
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": 5}''', '''{"key": "qwe"}''', '''{"key": {}}''', '''{"key": true}'''] loop
      perform test.assert_throw(
        'select json.get_array(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not an array');
      perform test.assert_throw(
        'select json.get_opt_array(' || v_json || '::' || v_json_type || ', ''[]''::' || v_json_type || ', ''key'')',
        '%key% is not an array');
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_bigint_should_throw_for_float_json()

-- DROP FUNCTION json_test.get_x_bigint_should_throw_for_float_json();

CREATE OR REPLACE FUNCTION json_test.get_x_bigint_should_throw_for_float_json()
  RETURNS void AS
$BODY$
declare
  v_json text := '''5.55''';
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    perform test.assert_throw(
      'select json.get_bigint(' || v_json || '::' || v_json_type || ')',
      'Json is not a bigint');
    perform test.assert_throw(
      'select json.get_opt_bigint(' || v_json || '::' || v_json_type || ', 5)',
      'Json is not a bigint');
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_bigint_should_throw_for_float_param()

-- DROP FUNCTION json_test.get_x_bigint_should_throw_for_float_param();

CREATE OR REPLACE FUNCTION json_test.get_x_bigint_should_throw_for_float_param()
  RETURNS void AS
$BODY$
declare
  v_json text := '''{"key": 5.55}''';
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    perform test.assert_throw(
      'select json.get_bigint(' || v_json || '::' || v_json_type || ', ''key'')',
      '%key% is not a bigint');
    perform test.assert_throw(
      'select json.get_opt_bigint(' || v_json || '::' || v_json_type || ', 5, ''key'')',
      '%key% is not a bigint');
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_bigint_should_throw_for_invalid_json_type()

-- DROP FUNCTION json_test.get_x_bigint_should_throw_for_invalid_json_type();

CREATE OR REPLACE FUNCTION json_test.get_x_bigint_should_throw_for_invalid_json_type()
  RETURNS void AS
$BODY$
declare
  v_json text;
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[]''', '''"qwe"''', '''{}''', '''true'''] loop
      perform test.assert_throw(
        'select json.get_bigint(' || v_json || '::' || v_json_type || ')',
        'Json is not a number');
      perform test.assert_throw(
        'select json.get_opt_bigint(' || v_json || '::' || v_json_type || ', 5)',
        'Json is not a number');
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_bigint_should_throw_for_invalid_param_type()

-- DROP FUNCTION json_test.get_x_bigint_should_throw_for_invalid_param_type();

CREATE OR REPLACE FUNCTION json_test.get_x_bigint_should_throw_for_invalid_param_type()
  RETURNS void AS
$BODY$
declare
  v_json text;
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": []}''', '''{"key": "qwe"}''', '''{"key": {}}''', '''{"key": true}'''] loop
      perform test.assert_throw(
        'select json.get_bigint(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not a number');
      perform test.assert_throw(
        'select json.get_opt_bigint(' || v_json || '::' || v_json_type || ', 5, ''key'')',
        '%key% is not a number');
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_boolean_should_throw_for_invalid_json_type()

-- DROP FUNCTION json_test.get_x_boolean_should_throw_for_invalid_json_type();

CREATE OR REPLACE FUNCTION json_test.get_x_boolean_should_throw_for_invalid_json_type()
  RETURNS void AS
$BODY$
declare
  v_json text;
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''5''', '''[]''', '''"qwe"''', '''{}'''] loop
      perform test.assert_throw(
        'select json.get_boolean(' || v_json || '::' || v_json_type || ')',
        'Json is not a boolean');
      perform test.assert_throw(
        'select json.get_opt_boolean(' || v_json || '::' || v_json_type || ', true)',
        'Json is not a boolean');
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_boolean_should_throw_for_invalid_param_type()

-- DROP FUNCTION json_test.get_x_boolean_should_throw_for_invalid_param_type();

CREATE OR REPLACE FUNCTION json_test.get_x_boolean_should_throw_for_invalid_param_type()
  RETURNS void AS
$BODY$
declare
  v_json text;
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": 5}''', '''{"key": []}''', '''{"key": "qwe"}''', '''{"key": {}}'''] loop
      perform test.assert_throw(
        'select json.get_boolean(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not a boolean');
      perform test.assert_throw(
        'select json.get_opt_boolean(' || v_json || '::' || v_json_type || ', true, ''key'')',
        '%key% is not a boolean');
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_integer_should_throw_for_float_json()

-- DROP FUNCTION json_test.get_x_integer_should_throw_for_float_json();

CREATE OR REPLACE FUNCTION json_test.get_x_integer_should_throw_for_float_json()
  RETURNS void AS
$BODY$
declare
  v_json text := '''5.55''';
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    perform test.assert_throw(
      'select json.get_integer(' || v_json || '::' || v_json_type || ')',
      'Json is not an integer');
    perform test.assert_throw(
      'select json.get_opt_integer(' || v_json || '::' || v_json_type || ', 5)',
      'Json is not an integer');
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_integer_should_throw_for_float_param()

-- DROP FUNCTION json_test.get_x_integer_should_throw_for_float_param();

CREATE OR REPLACE FUNCTION json_test.get_x_integer_should_throw_for_float_param()
  RETURNS void AS
$BODY$
declare
  v_json text := '''{"key": 5.55}''';
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    perform test.assert_throw(
      'select json.get_integer(' || v_json || '::' || v_json_type || ', ''key'')',
      '%key% is not an integer');
    perform test.assert_throw(
      'select json.get_opt_integer(' || v_json || '::' || v_json_type || ', 5, ''key'')',
      '%key% is not an integer');
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_integer_should_throw_for_invalid_json_type()

-- DROP FUNCTION json_test.get_x_integer_should_throw_for_invalid_json_type();

CREATE OR REPLACE FUNCTION json_test.get_x_integer_should_throw_for_invalid_json_type()
  RETURNS void AS
$BODY$
declare
  v_json text;
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[]''', '''"qwe"''', '''{}''', '''true'''] loop
      perform test.assert_throw(
        'select json.get_integer(' || v_json || '::' || v_json_type || ')',
        'Json is not a number');
      perform test.assert_throw(
        'select json.get_opt_integer(' || v_json || '::' || v_json_type || ', 5)',
        'Json is not a number');
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_integer_should_throw_for_invalid_param_type()

-- DROP FUNCTION json_test.get_x_integer_should_throw_for_invalid_param_type();

CREATE OR REPLACE FUNCTION json_test.get_x_integer_should_throw_for_invalid_param_type()
  RETURNS void AS
$BODY$
declare
  v_json text;
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": []}''', '''{"key": "qwe"}''', '''{"key": {}}''', '''{"key": true}'''] loop
      perform test.assert_throw(
        'select json.get_integer(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not a number');
      perform test.assert_throw(
        'select json.get_opt_integer(' || v_json || '::' || v_json_type || ', 5, ''key'')',
        '%key% is not a number');
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_object_should_throw_for_invalid_json_type()

-- DROP FUNCTION json_test.get_x_object_should_throw_for_invalid_json_type();

CREATE OR REPLACE FUNCTION json_test.get_x_object_should_throw_for_invalid_json_type()
  RETURNS void AS
$BODY$
declare
  v_json text;
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[]''', '''"qwe"''', '''5''', '''true'''] loop
      perform test.assert_throw(
        'select json.get_object(' || v_json || '::' || v_json_type || ')',
        'Json is not an object');
      perform test.assert_throw(
        'select json.get_opt_object(' || v_json || '::' || v_json_type || ', ' || '''{}''' || '::' || v_json_type || ')',
        'Json is not an object');
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_object_should_throw_for_invalid_param_type()

-- DROP FUNCTION json_test.get_x_object_should_throw_for_invalid_param_type();

CREATE OR REPLACE FUNCTION json_test.get_x_object_should_throw_for_invalid_param_type()
  RETURNS void AS
$BODY$
declare
  v_json text;
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": []}''', '''{"key": "qwe"}''', '''{"key": 5}''', '''{"key": true}'''] loop
      perform test.assert_throw(
        'select json.get_object(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not an object');
      perform test.assert_throw(
        'select json.get_opt_object(' || v_json || '::' || v_json_type || ', ' || '''{}''' || '::' || v_json_type || ', ''key'')',
        '%key% is not an object');
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_should_throw_for_non_existing_key()

-- DROP FUNCTION json_test.get_x_should_throw_for_non_existing_key();

CREATE OR REPLACE FUNCTION json_test.get_x_should_throw_for_non_existing_key()
  RETURNS void AS
$BODY$
declare
  v_json text := '''{"key1": "value1", "key2": 2}''';
  v_json_type text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_type in array array ['array', 'bigint', 'boolean', 'integer', 'object'] loop
      perform test.assert_throw(
        'select json.get_' || v_type || '(' || v_json || '::' || v_json_type || ', ''key3'')',
        '%key3%not found');
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_should_throw_for_null_json()

-- DROP FUNCTION json_test.get_x_should_throw_for_null_json();

CREATE OR REPLACE FUNCTION json_test.get_x_should_throw_for_null_json()
  RETURNS void AS
$BODY$
declare
  v_json_type text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_type in array array ['array', 'bigint', 'boolean', 'integer', 'object'] loop
      perform test.assert_throw(
        'select json.get_' || v_type || '(null::' || v_json_type || ')',
        'Json is not a%');
    end loop;
    foreach v_type in array array ['array', 'bigint', 'boolean', 'integer', 'object'] loop
      perform test.assert_throw(
        'select json.get_' || v_type || '(null::' || v_json_type || ', ''key3'')',
        '%key3%not found');
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_string_should_throw_for_invalid_json_type()

-- DROP FUNCTION json_test.get_x_string_should_throw_for_invalid_json_type();

CREATE OR REPLACE FUNCTION json_test.get_x_string_should_throw_for_invalid_json_type()
  RETURNS void AS
$BODY$
declare
  v_json text;
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[]''', '''5''', '''{}''', '''true'''] loop
      perform test.assert_throw(
        'select json.get_string(' || v_json || '::' || v_json_type || ')',
        'Json is not a string');
      perform test.assert_throw(
        'select json.get_opt_string(' || v_json || '::' || v_json_type || ', '''')',
        'Json is not a string');
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: json_test.get_x_string_should_throw_for_invalid_param_type()

-- DROP FUNCTION json_test.get_x_string_should_throw_for_invalid_param_type();

CREATE OR REPLACE FUNCTION json_test.get_x_string_should_throw_for_invalid_param_type()
  RETURNS void AS
$BODY$
declare
  v_json text;
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": []}''', '''{"key": 5}''', '''{"key": {}}''', '''{"key": true}'''] loop
      perform test.assert_throw(
        'select json.get_string(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not a string');
      perform test.assert_throw(
        'select json.get_opt_string(' || v_json || '::' || v_json_type || ', '''', ''key'')',
        '%key% is not a string');
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_caseeq(text, text)

-- DROP FUNCTION test.assert_caseeq(text, text);

CREATE OR REPLACE FUNCTION test.assert_caseeq(
    in_expected text,
    in_actual text)
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_casene(text, text)

-- DROP FUNCTION test.assert_casene(text, text);

CREATE OR REPLACE FUNCTION test.assert_casene(
    in_expected text,
    in_actual text)
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_eq(bigint, bigint)

-- DROP FUNCTION test.assert_eq(bigint, bigint);

CREATE OR REPLACE FUNCTION test.assert_eq(
    in_expected bigint,
    in_actual bigint)
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_eq(bigint[], bigint[])

-- DROP FUNCTION test.assert_eq(bigint[], bigint[]);

CREATE OR REPLACE FUNCTION test.assert_eq(
    in_expected bigint[],
    in_actual bigint[])
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_eq(json, json)

-- DROP FUNCTION test.assert_eq(json, json);

CREATE OR REPLACE FUNCTION test.assert_eq(
    in_expected json,
    in_actual json)
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_eq(jsonb, jsonb)

-- DROP FUNCTION test.assert_eq(jsonb, jsonb);

CREATE OR REPLACE FUNCTION test.assert_eq(
    in_expected jsonb,
    in_actual jsonb)
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_eq(text, text)

-- DROP FUNCTION test.assert_eq(text, text);

CREATE OR REPLACE FUNCTION test.assert_eq(
    in_expected text,
    in_actual text)
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_eq(text[], text[])

-- DROP FUNCTION test.assert_eq(text[], text[]);

CREATE OR REPLACE FUNCTION test.assert_eq(
    in_expected text[],
    in_actual text[])
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_false(boolean)

-- DROP FUNCTION test.assert_false(boolean);

CREATE OR REPLACE FUNCTION test.assert_false(in_expression boolean)
  RETURNS void AS
$BODY$
-- Проверяет, что выражение ложно
begin
  if in_expression is null or in_expression = true then
    raise exception 'Assert_false failed.';
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_ge(bigint, bigint)

-- DROP FUNCTION test.assert_ge(bigint, bigint);

CREATE OR REPLACE FUNCTION test.assert_ge(
    in_expected bigint,
    in_actual bigint)
  RETURNS void AS
$BODY$
-- Проверяет, что ожидаемое значение больше или равно реальному
begin
  if in_expected is null or in_actual is null or in_expected < in_actual then
    raise exception 'Assert_ge failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_gt(bigint, bigint)

-- DROP FUNCTION test.assert_gt(bigint, bigint);

CREATE OR REPLACE FUNCTION test.assert_gt(
    in_expected bigint,
    in_actual bigint)
  RETURNS void AS
$BODY$
-- Проверяет, что ожидаемое значение больше реального
begin
  if in_expected is null or in_actual is null or in_expected <= in_actual then
    raise exception 'Assert_gt failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_le(bigint, bigint)

-- DROP FUNCTION test.assert_le(bigint, bigint);

CREATE OR REPLACE FUNCTION test.assert_le(
    in_expected bigint,
    in_actual bigint)
  RETURNS void AS
$BODY$
-- Проверяет, что ожидаемое значение меньше или равно реальному
begin
  if in_expected is null or in_actual is null or in_expected > in_actual then
    raise exception 'Assert_le failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_lt(bigint, bigint)

-- DROP FUNCTION test.assert_lt(bigint, bigint);

CREATE OR REPLACE FUNCTION test.assert_lt(
    in_expected bigint,
    in_actual bigint)
  RETURNS void AS
$BODY$
-- Проверяет, что ожидаемое значение меньше реального
begin
  if in_expected is null or in_actual is null or in_expected >= in_actual then
    raise exception 'Assert_lt failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_ne(bigint, bigint)

-- DROP FUNCTION test.assert_ne(bigint, bigint);

CREATE OR REPLACE FUNCTION test.assert_ne(
    in_expected bigint,
    in_actual bigint)
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_ne(bigint[], bigint[])

-- DROP FUNCTION test.assert_ne(bigint[], bigint[]);

CREATE OR REPLACE FUNCTION test.assert_ne(
    in_expected bigint[],
    in_actual bigint[])
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_ne(json, json)

-- DROP FUNCTION test.assert_ne(json, json);

CREATE OR REPLACE FUNCTION test.assert_ne(
    in_expected json,
    in_actual json)
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_ne(jsonb, jsonb)

-- DROP FUNCTION test.assert_ne(jsonb, jsonb);

CREATE OR REPLACE FUNCTION test.assert_ne(
    in_expected jsonb,
    in_actual jsonb)
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_ne(text, text)

-- DROP FUNCTION test.assert_ne(text, text);

CREATE OR REPLACE FUNCTION test.assert_ne(
    in_expected text,
    in_actual text)
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_ne(text[], text[])

-- DROP FUNCTION test.assert_ne(text[], text[]);

CREATE OR REPLACE FUNCTION test.assert_ne(
    in_expected text[],
    in_actual text[])
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_not_null(bigint)

-- DROP FUNCTION test.assert_not_null(bigint);

CREATE OR REPLACE FUNCTION test.assert_not_null(in_expression bigint)
  RETURNS void AS
$BODY$
-- Проверяет, что выражение не является null
begin
  if in_expression is null then
    raise exception 'Assert_not_null failed.';
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_not_null(boolean)

-- DROP FUNCTION test.assert_not_null(boolean);

CREATE OR REPLACE FUNCTION test.assert_not_null(in_expression boolean)
  RETURNS void AS
$BODY$
-- Проверяет, что выражение не является null
begin
  if in_expression is null then
    raise exception 'Assert_not_null failed.';
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_not_null(text)

-- DROP FUNCTION test.assert_not_null(text);

CREATE OR REPLACE FUNCTION test.assert_not_null(in_expression text)
  RETURNS void AS
$BODY$
-- Проверяет, что выражение не является null
begin
  if in_expression is null then
    raise exception 'Assert_not_null failed.';
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_no_throw(text)

-- DROP FUNCTION test.assert_no_throw(text);

CREATE OR REPLACE FUNCTION test.assert_no_throw(in_expression text)
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: test.assert_null(bigint)

-- DROP FUNCTION test.assert_null(bigint);

CREATE OR REPLACE FUNCTION test.assert_null(in_expression bigint)
  RETURNS void AS
$BODY$
-- Проверяет, что выражение является null
begin
  if in_expression is not null then
    raise exception 'Assert_null failed.';
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_null(boolean)

-- DROP FUNCTION test.assert_null(boolean);

CREATE OR REPLACE FUNCTION test.assert_null(in_expression boolean)
  RETURNS void AS
$BODY$
-- Проверяет, что выражение является null
begin
  if in_expression is not null then
    raise exception 'Assert_null failed.';
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_null(text)

-- DROP FUNCTION test.assert_null(text);

CREATE OR REPLACE FUNCTION test.assert_null(in_expression text)
  RETURNS void AS
$BODY$
-- Проверяет, что выражение является null
begin
  if in_expression is not null then
    raise exception 'Assert_null failed.';
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.assert_throw(text, text)

-- DROP FUNCTION test.assert_throw(text, text);

CREATE OR REPLACE FUNCTION test.assert_throw(
    in_expression text,
    in_exception_pattern text DEFAULT NULL::text)
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: test.assert_true(boolean)

-- DROP FUNCTION test.assert_true(boolean);

CREATE OR REPLACE FUNCTION test.assert_true(in_expression boolean)
  RETURNS void AS
$BODY$
-- Проверяет, что выражение истинно
begin
  if in_expression is null or in_expression = false then
    raise exception 'Assert_true failed.';
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.fail(text)

-- DROP FUNCTION test.fail(text);

CREATE OR REPLACE FUNCTION test.fail(in_description text DEFAULT NULL::text)
  RETURNS void AS
$BODY$
-- Всегда генерирует исключение
begin
  if in_description is not null then
    raise exception 'Fail. Description: %', in_description;
  else
    raise exception 'Fail.';
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: test.run_all_tests()

-- DROP FUNCTION test.run_all_tests();

CREATE OR REPLACE FUNCTION test.run_all_tests()
  RETURNS boolean AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: user_api.get_extensions(text, integer, jsonb)

-- DROP FUNCTION user_api.get_extensions(text, integer, jsonb);

CREATE OR REPLACE FUNCTION user_api.get_extensions(
    in_client text,
    in_login_id integer,
    in_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_extensions json;
begin
  select coalesce(json_agg(f.code), json '[]')
  into v_extensions
  from (
    select code
    from data.extensions
    order by code
  ) f;

  return api_utils.create_ok_result(v_extensions);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: user_api.get_objects(text, integer, jsonb)

-- DROP FUNCTION user_api.get_objects(text, integer, jsonb);

CREATE OR REPLACE FUNCTION user_api.get_objects(
    in_client text,
    in_login_id integer,
    in_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_user_object_id integer := api_utils.get_user_object(in_login_id, in_params);
  v_object_codes text[];

  v_filter_result api_utils.objects_process_result;
  v_sort_result api_utils.objects_process_result;

  v_attributes text[];
  v_attribute_ids integer[];
  v_attributes_to_fill_ids integer[];

  v_objects jsonb;
  v_etag text;
  v_if_non_match text;
begin
  if v_user_object_id is null then
    return api_utils.create_forbidden_result('Invalid user object');
  end if;

  if in_params ? 'object_codes' then
    v_object_codes := json.get_string_array(in_params, 'object_codes');
  else
    v_object_codes := api_utils.get_object_codes_info_from_attribute(v_user_object_id, in_params);
  end if;

  v_filter_result := api_utils.get_filtered_object_ids(v_user_object_id, v_object_codes, in_params);
  if v_filter_result is null or v_filter_result.object_ids is null then
    return api_utils.create_not_found_result('There are no requested objects or user object don''t have enough privileges');
  end if;

  v_sort_result := api_utils.get_sorted_object_ids(v_user_object_id, v_filter_result.object_ids, v_filter_result.filled_attributes_ids, in_params);

  v_sort_result.object_ids := api_utils.limit_object_ids(v_sort_result.object_ids, in_params);

  if in_params ? 'attributes' then
    v_attributes := json.get_string_array(in_params, 'attributes');

    select array_agg(id)
    into v_attribute_ids
    from data.attributes
    where code = any(v_attributes);

    select array_agg(id)
    into v_attributes_to_fill_ids
    from data.attributes
    where
      id = any(v_attribute_ids) and
      id != any(v_sort_result.filled_attributes_ids);
  else
    select array_agg(id)
    into v_attribute_ids
    from data.attributes
    where type in ('NORMAL', 'HIDDEN');

    select array_agg(id)
    into v_attributes_to_fill_ids
    from data.attributes
    where
      id = any(v_attribute_ids) and
      id != any(v_sort_result.filled_attributes_ids);
  end if;

  if v_attributes_to_fill_ids is not null then
    perform data.fill_attribute_values(v_user_object_id, v_sort_result.object_ids, v_attributes_to_fill_ids);
  end if;

  v_objects :=
    api_utils.get_objects_infos(
      v_user_object_id,
      v_sort_result.object_ids,
      v_attribute_ids,
      json.get_opt_boolean(in_params, true, 'get_actions'),
      json.get_opt_boolean(in_params, true, 'get_templates'));

  v_etag := encode(pgcrypto.digest(v_objects::text, 'sha256'), 'base64');

  v_if_non_match := json.get_opt_string(in_params, null, 'if_non_match');
  if
    v_if_non_match is not null and
    v_if_non_match = v_etag
  then
    return api_utils.create_not_modified_result();
  end if;

  return api_utils.create_ok_result(
    json_build_object(
      'etag', v_etag,
      'objects', v_objects));
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: user_api.get_user_objects(text, integer, jsonb)

-- DROP FUNCTION user_api.get_user_objects(text, integer, jsonb);

CREATE OR REPLACE FUNCTION user_api.get_user_objects(
    in_client text,
    in_login_id integer,
    in_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_name_attribute_id integer;
  v_name_attribute_name text;
  v_objects jsonb;
  v_etag text;
  v_if_non_match text;
begin
  perform data.fill_attribute_values(object_id, array[object_id], array[v_name_attribute_id])
  from data.login_objects
  where login_id = in_login_id;

  select id, name
  into v_name_attribute_id, v_name_attribute_name
  from data.attributes
  where
    code = 'name' and
    type = 'NORMAL';

  if v_name_attribute_id is null then
    raise exception 'Can''t find normal attribute "name"';
  end if;

  select
    jsonb_agg(
      jsonb_build_object(
        'code',
        code) ||
      case when value is not null then
        jsonb_build_object(
          'attributes',
          jsonb_build_object(
            'name',
            jsonb_build_object(
              'name',
              v_name_attribute_name,
              'value',
              value)))
      else jsonb '{}' end)
  into v_objects
  from (
    select o.code, data.get_attribute_value(o.id, o.id, v_name_attribute_id) as value
    from data.login_objects lo
    join data.objects o on
      login_id = in_login_id and
      o.id = lo.object_id
    order by value, code
  ) v;

  v_etag := encode(pgcrypto.digest(coalesce(v_objects::text, ''), 'sha256'), 'base64');

  v_if_non_match := json.get_opt_string(in_params, null, 'if_non_match');
  if
    v_if_non_match is not null and
    v_if_non_match = v_etag
  then
    return api_utils.create_not_modified_result();
  end if;

  return api_utils.create_ok_result(
    json_build_object(
      'etag', v_etag,
      'objects', v_objects));
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: user_api.make_action(text, integer, jsonb)

-- DROP FUNCTION user_api.make_action(text, integer, jsonb);

CREATE OR REPLACE FUNCTION user_api.make_action(
    in_client text,
    in_login_id integer,
    in_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_user_object_id integer := api_utils.get_user_object(in_login_id, in_params);
  v_action_code text;
  v_params jsonb;
  v_user_params jsonb;

  v_generator integer;
  v_checksum text;

  v_generator_code text;

  v_ret_val api.result;
begin
  if v_user_object_id is null then
    return api_utils.create_forbidden_result('Invalid user object');
  end if;

  v_action_code := json.get_string(in_params, 'action_code');
  v_params := json.get_object(in_params, 'params');
  v_user_params := json.get_opt_object(in_params, null, 'user_params');

  v_generator := json.get_integer(v_params, 'generator');
  v_checksum := json.get_string(v_params, 'checksum');

  select code
  into v_generator_code
  from data.action_generators
  where id = v_generator;

  v_params := v_params - 'generator' - 'checksum';

  if v_generator_code is null then
    return api_utils.create_conflict_result('Invalid action generator');
  elsif v_checksum != data.create_checksum(v_user_object_id, v_generator_code, v_action_code, v_params) then
    return api_utils.create_conflict_result('Invalid checksum');
  end if;

  execute format('select * from actions.%s($1, $2, $3, $4)', v_action_code)
  using in_client, v_user_object_id, v_params, v_user_params
  into v_ret_val;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: utils.integer_array_idx(integer[], integer)

-- DROP FUNCTION utils.integer_array_idx(integer[], integer);

CREATE OR REPLACE FUNCTION utils.integer_array_idx(
    in_array integer[],
    in_value integer)
  RETURNS integer AS
$BODY$
declare
  v_idx integer;
begin
  select num
  into v_idx
  from (
    select row_number() over() as num, s.value
    from unnest(in_array) s(value)
  ) s
  where s.value = in_value
  limit 1;

  return v_idx;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: utils.raise_invalid_input_param_value(text)

-- DROP FUNCTION utils.raise_invalid_input_param_value(text);

CREATE OR REPLACE FUNCTION utils.raise_invalid_input_param_value(in_message text)
  RETURNS bigint AS
$BODY$
begin
  assert in_message is not null;

  raise '%', in_message using errcode = 'invalid_parameter_value';
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: utils.raise_invalid_input_param_value(text, text)

-- DROP FUNCTION utils.raise_invalid_input_param_value(text, text);

CREATE OR REPLACE FUNCTION utils.raise_invalid_input_param_value(
    in_format text,
    in_param text)
  RETURNS bigint AS
$BODY$
begin
  assert in_format is not null;
  assert in_param is not null;

  raise '%', format(in_format, in_param) using errcode = 'invalid_parameter_value';
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: utils.raise_invalid_input_param_value(text, text, text)

-- DROP FUNCTION utils.raise_invalid_input_param_value(text, text, text);

CREATE OR REPLACE FUNCTION utils.raise_invalid_input_param_value(
    in_format text,
    in_param1 text,
    in_param2 text)
  RETURNS bigint AS
$BODY$
begin
  assert in_format is not null;
  assert in_param1 is not null;
  assert in_param1 is not null;

  raise '%', format(in_format, in_param1, in_param2) using errcode = 'invalid_parameter_value';
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: utils.random_bigint(bigint, bigint)

-- DROP FUNCTION utils.random_bigint(bigint, bigint);

CREATE OR REPLACE FUNCTION utils.random_bigint(
    in_min_value bigint,
    in_max_value bigint)
  RETURNS bigint AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: utils.random_integer(integer, integer)

-- DROP FUNCTION utils.random_integer(integer, integer);

CREATE OR REPLACE FUNCTION utils.random_integer(
    in_min_value integer,
    in_max_value integer)
  RETURNS integer AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
-- Function: utils.string_array_after(text[], text)

-- DROP FUNCTION utils.string_array_after(text[], text);

CREATE OR REPLACE FUNCTION utils.string_array_after(
    in_array text[],
    in_value text)
  RETURNS text[] AS
$BODY$
declare
  v_ret_val text[];
begin
  select array_agg(value)
  into v_ret_val
  from (
    select
      row_number() over() as num,
      value
    from unnest(in_array) s(value)
  ) f
  where f.num > coalesce(utils.string_array_idx(in_array, in_value), 0);

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: utils.string_array_idx(text[], text)

-- DROP FUNCTION utils.string_array_idx(text[], text);

CREATE OR REPLACE FUNCTION utils.string_array_idx(
    in_array text[],
    in_value text)
  RETURNS integer AS
$BODY$
declare
  v_idx integer;
begin
  select num
  into v_idx
  from (
    select row_number() over() as num, s.value
    from unnest(in_array) s(value)
  ) s
  where s.value = in_value
  limit 1;

  return v_idx;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: utils_test.random_x_should_return_exact_value()

-- DROP FUNCTION utils_test.random_x_should_return_exact_value();

CREATE OR REPLACE FUNCTION utils_test.random_x_should_return_exact_value()
  RETURNS void AS
$BODY$
declare
  v_type text;
  v_value text := '5';
begin
  foreach v_type in array array ['bigint', 'integer'] loop
    execute 'select test.assert_eq(5, utils.random_' || v_type || '(' || v_value || ', ' || v_value || '))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: utils_test.random_x_should_return_ge_than_min_value()

-- DROP FUNCTION utils_test.random_x_should_return_ge_than_min_value();

CREATE OR REPLACE FUNCTION utils_test.random_x_should_return_ge_than_min_value()
  RETURNS void AS
$BODY$
declare
  v_type text;
  v_min_value text := '-5';
  v_max_value text := '-2';
begin
  foreach v_type in array array ['bigint', 'integer'] loop
    execute 'select test.assert_le(' || v_min_value || ', utils.random_' || v_type || '(' || v_min_value || ', ' || v_max_value || '))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Function: utils_test.random_x_should_return_le_than_max_value()

-- DROP FUNCTION utils_test.random_x_should_return_le_than_max_value();

CREATE OR REPLACE FUNCTION utils_test.random_x_should_return_le_than_max_value()
  RETURNS void AS
$BODY$
declare
  v_type text;
  v_min_value text := '2';
  v_max_value text := '5';
begin
  foreach v_type in array array ['bigint', 'integer'] loop
    execute 'select test.assert_ge(' || v_max_value || ', utils.random_' || v_type || '(' || v_min_value || ', ' || v_max_value || '))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
-- Tables
-- Table: data.action_generators

-- DROP TABLE data.action_generators;

CREATE TABLE data.action_generators
(
  id serial NOT NULL,
  code text NOT NULL DEFAULT (pgcrypto.gen_random_uuid())::text,
  function text NOT NULL, -- coalesce(params, jsonb '{}') || jsonb_build_object('user_object_id', <user_obj_id>, 'object_id', <obj_id> | null)
  params jsonb,
  description text,
  CONSTRAINT action_generators_pk PRIMARY KEY (id),
  CONSTRAINT action_generators_unique_code UNIQUE (code)
)
WITH (
  OIDS=FALSE
);
COMMENT ON COLUMN data.action_generators.function IS 'coalesce(params, jsonb ''{}'') || jsonb_build_object(''user_object_id'', <user_obj_id>, ''object_id'', <obj_id> | null)';

-- Table: data.attributes

-- DROP TABLE data.attributes;

CREATE TABLE data.attributes
(
  id serial NOT NULL,
  code text NOT NULL,
  name text,
  description text,
  type data.attribute_type NOT NULL,
  value_description_function text, -- (user_object_id, attribute_id, value)
  CONSTRAINT attributes_pk PRIMARY KEY (id),
  CONSTRAINT attributes_unique_code UNIQUE (code)
)
WITH (
  OIDS=FALSE
);
COMMENT ON COLUMN data.attributes.value_description_function IS '(user_object_id, attribute_id, value)';

-- Table: data.deferred_functions

-- DROP TABLE data.deferred_functions;

CREATE TABLE data.deferred_functions
(
  id serial NOT NULL,
  code text NOT NULL,
  run_time timestamp with time zone NOT NULL,
  function text NOT NULL,
  params jsonb,
  start_time timestamp with time zone NOT NULL DEFAULT now(),
  start_reason text,
  start_object_id integer,
  CONSTRAINT deferred_functions_pk PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);

-- Index: data.deferred_functions_idx_code

-- DROP INDEX data.deferred_functions_idx_code;

CREATE INDEX deferred_functions_idx_code
  ON data.deferred_functions
  USING btree
  (code COLLATE pg_catalog."default");

-- Index: data.deferred_functions_idx_rt

-- DROP INDEX data.deferred_functions_idx_rt;

CREATE INDEX deferred_functions_idx_rt
  ON data.deferred_functions
  USING btree
  (run_time);

-- Table: data.deferred_functions_journal

-- DROP TABLE data.deferred_functions_journal;

CREATE TABLE data.deferred_functions_journal
(
  id serial NOT NULL,
  code text NOT NULL,
  run_time timestamp with time zone NOT NULL,
  function text NOT NULL,
  params jsonb,
  start_time timestamp with time zone NOT NULL DEFAULT now(),
  start_reason text,
  start_object_id integer,
  end_time timestamp with time zone NOT NULL,
  end_reason text,
  end_object_id integer,
  CONSTRAINT deferred_functions_journal_pk PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);
-- Table: data.extensions

-- DROP TABLE data.extensions;

CREATE TABLE data.extensions
(
  code text NOT NULL,
  CONSTRAINT extensions_unique_code UNIQUE (code)
)
WITH (
  OIDS=FALSE
);
-- Table: data.logins

-- DROP TABLE data.logins;

CREATE TABLE data.logins
(
  id serial NOT NULL,
  code text,
  description text,
  is_admin boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  CONSTRAINT logins_pk PRIMARY KEY (id),
  CONSTRAINT logins_unique_code UNIQUE (code)
)
WITH (
  OIDS=FALSE
);
-- Table: data.objects

-- DROP TABLE data.objects;

CREATE TABLE data.objects
(
  id serial NOT NULL,
  code text NOT NULL DEFAULT (pgcrypto.gen_random_uuid())::text,
  CONSTRAINT objects_pk PRIMARY KEY (id),
  CONSTRAINT objects_unique_code UNIQUE (code)
)
WITH (
  OIDS=FALSE
);

-- Trigger: objects_trigger_after_insert on data.objects

-- DROP TRIGGER objects_trigger_after_insert ON data.objects;

CREATE TRIGGER objects_trigger_after_insert
  AFTER INSERT
  ON data.objects
  FOR EACH ROW
  EXECUTE PROCEDURE data.objects_after_insert();

-- Table: data.params

-- DROP TABLE data.params;

CREATE TABLE data.params
(
  id serial NOT NULL,
  code text NOT NULL,
  value jsonb NOT NULL,
  description text,
  CONSTRAINT params_pk PRIMARY KEY (id),
  CONSTRAINT params_unique_code UNIQUE (code)
)
WITH (
  OIDS=FALSE
);
-- Table: data.attribute_values

-- DROP TABLE data.attribute_values;

CREATE TABLE data.attribute_values
(
  id serial NOT NULL,
  object_id integer NOT NULL,
  attribute_id integer NOT NULL,
  value_object_id integer,
  value jsonb,
  start_time timestamp with time zone NOT NULL DEFAULT now(),
  start_reason text,
  start_object_id integer,
  CONSTRAINT attribute_values_pk PRIMARY KEY (id),
  CONSTRAINT attribute_values_fk_attribute FOREIGN KEY (attribute_id)
      REFERENCES data.attributes (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT attribute_values_fk_object FOREIGN KEY (object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT attribute_values_fk_start_object FOREIGN KEY (start_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT attribute_values_fk_value_object FOREIGN KEY (value_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);

-- Index: data.attribute_values_idx_oi_ai

-- DROP INDEX data.attribute_values_idx_oi_ai;

CREATE UNIQUE INDEX attribute_values_idx_oi_ai
  ON data.attribute_values
  USING btree
  (object_id, attribute_id)
  WHERE value_object_id IS NULL;

-- Index: data.attribute_values_idx_oi_ai_voi

-- DROP INDEX data.attribute_values_idx_oi_ai_voi;

CREATE UNIQUE INDEX attribute_values_idx_oi_ai_voi
  ON data.attribute_values
  USING btree
  (object_id, attribute_id, value_object_id)
  WHERE value_object_id IS NOT NULL;

-- Table: data.attribute_values_journal

-- DROP TABLE data.attribute_values_journal;

CREATE TABLE data.attribute_values_journal
(
  id serial NOT NULL,
  object_id integer NOT NULL,
  attribute_id integer NOT NULL,
  value_object_id integer,
  value jsonb,
  start_time timestamp with time zone NOT NULL,
  start_reason text,
  start_object_id integer,
  end_time timestamp with time zone NOT NULL,
  end_reason text,
  end_object_id integer,
  CONSTRAINT attribute_values_journal_pk PRIMARY KEY (id),
  CONSTRAINT attribute_values_journal_fk_attribute FOREIGN KEY (attribute_id)
      REFERENCES data.attributes (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT attribute_values_journal_fk_end_object FOREIGN KEY (end_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT attribute_values_journal_fk_object FOREIGN KEY (object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT attribute_values_journal_fk_start_object FOREIGN KEY (start_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT attribute_values_journal_fk_value_object FOREIGN KEY (value_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);
-- Table: data.attribute_value_change_functions

-- DROP TABLE data.attribute_value_change_functions;

CREATE TABLE data.attribute_value_change_functions
(
  id serial NOT NULL,
  attribute_id integer NOT NULL,
  function text NOT NULL, -- coalesce(params, jsonb '{}') || jsonb_build_object('user_object_id', <user_obj_id>, 'object_id', <obj_id>, 'attribute_id', <attr_id>, 'value_object_id', <value_obj_id>, 'old_value', <old_value>, 'new_value', <new_value>)
  params jsonb,
  description text,
  CONSTRAINT attribute_value_change_functions_pk PRIMARY KEY (id),
  CONSTRAINT attribute_value_change_functions_fk_attributes FOREIGN KEY (attribute_id)
      REFERENCES data.attributes (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);
COMMENT ON COLUMN data.attribute_value_change_functions.function IS 'coalesce(params, jsonb ''{}'') || jsonb_build_object(''user_object_id'', <user_obj_id>, ''object_id'', <obj_id>, ''attribute_id'', <attr_id>, ''value_object_id'', <value_obj_id>, ''old_value'', <old_value>, ''new_value'', <new_value>)';

-- Table: data.attribute_value_fill_functions

-- DROP TABLE data.attribute_value_fill_functions;

CREATE TABLE data.attribute_value_fill_functions
(
  id serial NOT NULL,
  attribute_id integer NOT NULL,
  function text NOT NULL, -- coalesce(params, jsonb '{}') || jsonb_build_object('user_object_id', <user_obj_id>, 'object_id', <obj_id>, 'attribute_id', <attr_id>)
  params jsonb,
  description text,
  CONSTRAINT attribute_value_fill_functions_pk PRIMARY KEY (id),
  CONSTRAINT attribute_value_fill_functions_fk_attributes FOREIGN KEY (attribute_id)
      REFERENCES data.attributes (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT attribute_value_fill_functions_unique_ai UNIQUE (attribute_id)
)
WITH (
  OIDS=FALSE
);
COMMENT ON COLUMN data.attribute_value_fill_functions.function IS 'coalesce(params, jsonb ''{}'') || jsonb_build_object(''user_object_id'', <user_obj_id>, ''object_id'', <obj_id>, ''attribute_id'', <attr_id>)';

-- Table: data.client_login

-- DROP TABLE data.client_login;

CREATE TABLE data.client_login
(
  id serial NOT NULL,
  client text NOT NULL,
  login_id integer NOT NULL,
  start_time timestamp with time zone NOT NULL DEFAULT now(),
  start_reason text,
  start_object_id integer,
  CONSTRAINT client_login_pk PRIMARY KEY (id),
  CONSTRAINT client_login_fk_login FOREIGN KEY (login_id)
      REFERENCES data.logins (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT client_login_fk_start_object FOREIGN KEY (start_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT client_login_unique_client UNIQUE (client)
)
WITH (
  OIDS=FALSE
);
-- Table: data.client_login_journal

-- DROP TABLE data.client_login_journal;

CREATE TABLE data.client_login_journal
(
  id serial NOT NULL,
  client text NOT NULL,
  login_id integer NOT NULL,
  start_time timestamp with time zone NOT NULL,
  start_reason text,
  start_object_id integer,
  end_time timestamp with time zone NOT NULL,
  end_reason text,
  end_object_id integer,
  CONSTRAINT client_login_journal_pk PRIMARY KEY (id),
  CONSTRAINT client_login_journal_fk_end_object FOREIGN KEY (end_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT client_login_journal_fk_login FOREIGN KEY (login_id)
      REFERENCES data.logins (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT client_login_journal_fk_start_object FOREIGN KEY (start_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);
-- Table: data.log

-- DROP TABLE data.log;

CREATE TABLE data.log
(
  id serial NOT NULL,
  severity data.severity NOT NULL,
  event_time timestamp with time zone NOT NULL DEFAULT now(),
  message text NOT NULL,
  client text,
  login_id integer,
  CONSTRAINT log_pk PRIMARY KEY (id),
  CONSTRAINT log_fk_login FOREIGN KEY (login_id)
      REFERENCES data.logins (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);
-- Table: data.login_objects

-- DROP TABLE data.login_objects;

CREATE TABLE data.login_objects
(
  id serial NOT NULL,
  login_id integer NOT NULL,
  object_id integer NOT NULL,
  start_time timestamp with time zone NOT NULL DEFAULT now(),
  start_reason text,
  start_object_id integer,
  CONSTRAINT login_objects_pk PRIMARY KEY (id),
  CONSTRAINT login_objects_fk_login FOREIGN KEY (login_id)
      REFERENCES data.logins (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT login_objects_fk_object FOREIGN KEY (object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT login_objects_fk_start_object FOREIGN KEY (start_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT login_objects_unique_li_oi UNIQUE (login_id, object_id)
)
WITH (
  OIDS=FALSE
);
-- Table: data.login_objects_journal

-- DROP TABLE data.login_objects_journal;

CREATE TABLE data.login_objects_journal
(
  id serial NOT NULL,
  login_id integer NOT NULL,
  object_id integer NOT NULL,
  start_time timestamp with time zone NOT NULL,
  start_reason text,
  start_object_id integer,
  end_time timestamp with time zone NOT NULL,
  end_reason text,
  end_object_id integer,
  CONSTRAINT login_objects_journal_pk PRIMARY KEY (id),
  CONSTRAINT login_objects_journal_fk_end_object FOREIGN KEY (end_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT login_objects_journal_fk_login FOREIGN KEY (login_id)
      REFERENCES data.logins (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT login_objects_journal_fk_object FOREIGN KEY (object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT login_objects_journal_fk_start_object FOREIGN KEY (start_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);
-- Table: data.object_objects

-- DROP TABLE data.object_objects;

CREATE TABLE data.object_objects
(
  id serial NOT NULL,
  parent_object_id integer NOT NULL,
  object_id integer NOT NULL,
  intermediate_object_ids integer[],
  start_time timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT object_objects_pk PRIMARY KEY (id),
  CONSTRAINT object_objects_fk_object FOREIGN KEY (object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT object_objects_fk_parent_object FOREIGN KEY (parent_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT object_objects_intermediate_object_ids_check CHECK (intarray.uniq(intarray.sort(intermediate_object_ids)) = intarray.sort(intermediate_object_ids))
)
WITH (
  OIDS=FALSE
);

-- Index: data.object_objects_idx_loi_goi

-- DROP INDEX data.object_objects_idx_loi_goi;

CREATE UNIQUE INDEX object_objects_idx_loi_goi
  ON data.object_objects
  USING btree
  ((LEAST(parent_object_id, object_id)), (GREATEST(parent_object_id, object_id)))
  WHERE intermediate_object_ids IS NULL;

-- Index: data.object_objects_idx_poi_oi

-- DROP INDEX data.object_objects_idx_poi_oi;

CREATE UNIQUE INDEX object_objects_idx_poi_oi
  ON data.object_objects
  USING btree
  (parent_object_id, object_id)
  WHERE intermediate_object_ids IS NULL;

-- Index: data.object_objects_idx_poi_oi_ioi

-- DROP INDEX data.object_objects_idx_poi_oi_ioi;

CREATE UNIQUE INDEX object_objects_idx_poi_oi_ioi
  ON data.object_objects
  USING btree
  (parent_object_id, object_id, intarray.uniq(intarray.sort(intermediate_object_ids)))
  WHERE intermediate_object_ids IS NOT NULL;

-- Table: data.object_objects_journal

-- DROP TABLE data.object_objects_journal;

CREATE TABLE data.object_objects_journal
(
  id serial NOT NULL,
  parent_object_id integer NOT NULL,
  object_id integer NOT NULL,
  intermediate_object_ids integer[],
  start_time timestamp with time zone NOT NULL,
  end_time timestamp with time zone NOT NULL,
  CONSTRAINT object_objects_journal_pk PRIMARY KEY (id),
  CONSTRAINT object_objects_journal_fk_object FOREIGN KEY (object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT object_objects_journal_fk_parent_object FOREIGN KEY (parent_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);
-- Initial data
insert into data.attributes(type, code, name, description) values
('SYSTEM', 'system_priority', 'Приоритет объекта', 'Используется для определения используемого значения атрибута в случае, когда есть несколько значений для разных объектов, в которые входит объект, от имени которого происходит действие. Приоритет для значения без объекта считается равным нулю.'),
('SYSTEM', 'system_is_visible', 'Видимость объекта', 'Если значение равно "true", то объект виден.');

insert into data.logins(description) values
('Бесправный пользователь для работы без авторизации');

insert into data.params(code, value, description)
select 'default_login', to_jsonb(l.id), 'Идентификатор бесправного login''а для входа без авторизации'
from data.logins l;