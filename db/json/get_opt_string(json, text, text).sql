-- Function: json.get_opt_string(json, text, text)

-- DROP FUNCTION json.get_opt_string(json, text, text);

CREATE OR REPLACE FUNCTION json.get_opt_string(
    in_json json,
    in_default text DEFAULT NULL::text,
    in_name text DEFAULT NULL::text)
  RETURNS text AS
$BODY$
declare
  v_param jsonb;
  v_param_type text;
begin
  if in_name is not null then
    v_param := in_json->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := json_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'string' then
    if in_name is not null then
      raise exception 'Attribute "%" is not a string', in_name;
    else
      raise exception 'Json is not a string';
    end if;
  end if;

  return v_param#>>'{}';
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
