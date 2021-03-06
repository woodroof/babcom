-- drop function json.get_bigint_array(json, text);

create or replace function json.get_bigint_array(in_json json, in_name text default null::text)
returns bigint[]
immutable
as
$$
declare
  v_array json := json.get_array(in_json, in_name);
  v_array_len integer := json_array_length(v_array);
  v_ret_val bigint[] := array[]::bigint[];
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
language plpgsql;
