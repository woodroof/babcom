-- Function: json.get_opt_object(jsonb, jsonb, text)

-- DROP FUNCTION json.get_opt_object(jsonb, jsonb, text);

CREATE OR REPLACE FUNCTION json.get_opt_object(
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

  if v_default_type is not null and v_default_type != 'object' then
    raise exception 'Default value "%" is not an object', in_default::text;
  end if;

  if in_name is not null then
    v_param := in_json->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := jsonb_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'object' then
    raise exception 'Attribute "%" is not an object', in_name;
  end if;
  return v_param;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
