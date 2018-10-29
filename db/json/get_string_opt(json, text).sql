-- drop function json.get_string_opt(json, text);

create or replace function json.get_string_opt(in_json json, in_default text)
immutable
returns text as
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
