-- Function: json.get_string(json, text)

-- DROP FUNCTION json.get_string(json, text);

CREATE OR REPLACE FUNCTION json.get_string(
    in_json json,
    in_name text DEFAULT NULL::text)
  RETURNS text AS
$BODY$
declare
  v_param json;
  v_param_type text;
begin
  if in_name is not null then
    v_param := in_json->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := json_typeof(v_param);

  if v_param_type is null then
    raise exception 'Attribute "%" was not found', in_name;
  end if;
  if v_param_type != 'string' then
    raise exception 'Attribute "%" is not a string', in_name;
  end if;
  return v_param#>>'{}';
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
