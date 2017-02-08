-- Function: json.get_if_array(jsonb, jsonb, text)

-- DROP FUNCTION json.get_if_array(jsonb, jsonb, text);

CREATE OR REPLACE FUNCTION json.get_if_array(
    in_json jsonb,
    in_default jsonb DEFAULT NULL::jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS jsonb AS
$BODY$
declare
  v_default_type text;
  v_param jsonb;
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

  if jsonb_typeof(v_param) = 'array' then
    return v_param;
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
