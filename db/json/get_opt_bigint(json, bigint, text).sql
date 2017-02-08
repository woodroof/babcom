-- Function: json.get_opt_bigint(json, bigint, text)

-- DROP FUNCTION json.get_opt_bigint(json, bigint, text);

CREATE OR REPLACE FUNCTION json.get_opt_bigint(
    in_json json,
    in_default bigint DEFAULT NULL::bigint,
    in_name text DEFAULT NULL::text)
  RETURNS bigint AS
$BODY$
declare
  v_param json;
  v_param_type text;
  v_ret_val bigint;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := json_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'number' then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not a number');
    end if;
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not a bigint', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not a bigint');
    end if;
  end;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
