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
