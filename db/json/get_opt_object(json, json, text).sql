-- Function: json.get_opt_object(json, json, text)

-- DROP FUNCTION json.get_opt_object(json, json, text);

CREATE OR REPLACE FUNCTION json.get_opt_object(
    in_json json,
    in_default json DEFAULT NULL::json,
    in_name text DEFAULT NULL::text)
  RETURNS json AS
$BODY$
declare
  v_default_type text;
  v_param json;
  v_param_type text;
begin
  v_default_type := json_typeof(in_default);

  if v_default_type is not null and v_default_type != 'object' then
    raise exception 'Default value "%" is not an object', in_default::text;
  end if;

  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := json_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'object' then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not an object', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not an object');
    end if;
  end if;

  return v_param;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
