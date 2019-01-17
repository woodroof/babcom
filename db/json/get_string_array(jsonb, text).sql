-- drop function json.get_string_array(jsonb, text);

create or replace function json.get_string_array(in_json jsonb, in_name text default null::text)
returns text[]
immutable
as
$$
declare
  v_array jsonb := json.get_array(in_json, in_name);
  v_array_len integer := jsonb_array_length(v_array);
  v_ret_val text[] := array[]::text[];
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
