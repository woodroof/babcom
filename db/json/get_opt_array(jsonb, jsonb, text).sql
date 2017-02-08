-- Function: json.get_opt_array(jsonb, jsonb, text)

-- DROP FUNCTION json.get_opt_array(jsonb, jsonb, text);

CREATE OR REPLACE FUNCTION json.get_opt_array(
    in_json jsonb,
    in_default jsonb DEFAULT NULL::jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS jsonb AS
$BODY$
declare
  v_default_type text;
  v_param jsonb;
  v_param_type text;
begin
  v_default_type := jsonb_typeof(in_default);

  if v_default_type is not null and v_default_type != 'array' then
    raise exception 'Default value "%" is not an array', in_default::text;
  end if;

  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := jsonb_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'array' then
    if in_name is not null then
      perform utils.raise_invalid_input_param_value('Attribute "%s" is not an array', in_name);
    else
      perform utils.raise_invalid_input_param_value('Json is not an array');
    end if;
  end if;

  return v_param;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
