-- Function: json.get_if_string(jsonb, text, text)

-- DROP FUNCTION json.get_if_string(jsonb, text, text);

CREATE OR REPLACE FUNCTION json.get_if_string(
    in_json jsonb,
    in_default text DEFAULT NULL::text,
    in_name text DEFAULT NULL::text)
  RETURNS text AS
$BODY$
declare
  v_param jsonb;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  if jsonb_typeof(v_param) = 'string' then
    return v_param#>>'{}';
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
