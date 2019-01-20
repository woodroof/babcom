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
