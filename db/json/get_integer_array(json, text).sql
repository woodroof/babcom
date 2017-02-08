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
