-- drop function json.get_object_opt(json, json);

create or replace function json.get_object_opt(in_json json, in_default json)
immutable
returns json as
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
