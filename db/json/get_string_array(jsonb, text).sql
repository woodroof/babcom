-- Function: json.get_string_array(jsonb, text)

-- DROP FUNCTION json.get_string_array(jsonb, text);

CREATE OR REPLACE FUNCTION json.get_string_array(
    in_json jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS text[] AS
$BODY$
declare
  v_array jsonb := json.get_array(in_json, in_name);
  v_array_len integer := jsonb_array_length(v_array);
  v_ret_val text[];
begin
  if v_array_len < 1 then
    raise invalid_parameter_value;
  end if;

  for i in 0 .. v_array_len - 1 loop
    v_ret_val := array_append(v_ret_val, json.get_string(v_array->i));
  end loop;

  return v_ret_val;
exception when invalid_parameter_value then
  if in_name is not null then
    perform utils.raise_invalid_input_param_value('Attribute "%s" is not a string array', in_name);
  else
    perform utils.raise_invalid_input_param_value('Json is not a string array');
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;