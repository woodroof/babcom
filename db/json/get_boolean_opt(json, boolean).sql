-- drop function json.get_boolean_opt(json, boolean);

create or replace function json.get_boolean_opt(in_json json, in_default boolean)
immutable
returns boolean as
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
