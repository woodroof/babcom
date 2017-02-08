-- Function: json.get_if_array(json, json, text)

-- DROP FUNCTION json.get_if_array(json, json, text);

CREATE OR REPLACE FUNCTION json.get_if_array(
    in_json json,
    in_default json DEFAULT NULL::json,
    in_name text DEFAULT NULL::text)
  RETURNS json AS
$BODY$
declare
  v_default_type text;
  v_param json;
begin
  v_default_type := json_typeof(in_default);

  if v_default_type is not null and v_default_type != 'array' then
    raise exception 'Default value "%" is not an array', in_default::text;
  end if;

  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  if json_typeof(v_param) = 'array' then
    return v_param;
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
