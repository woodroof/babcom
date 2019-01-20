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
