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
