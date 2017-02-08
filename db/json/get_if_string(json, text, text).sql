-- Function: json.get_if_string(json, text, text)

-- DROP FUNCTION json.get_if_string(json, text, text);

CREATE OR REPLACE FUNCTION json.get_if_string(
    in_json json,
    in_default text DEFAULT NULL::text,
    in_name text DEFAULT NULL::text)
  RETURNS text AS
$BODY$
declare
  v_param json;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  if json_typeof(v_param) = 'string' then
    return v_param#>>'{}';
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
