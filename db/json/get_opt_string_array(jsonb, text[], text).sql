-- Function: json.get_opt_string_array(jsonb, text[], text)

-- DROP FUNCTION json.get_opt_string_array(jsonb, text[], text);

CREATE OR REPLACE FUNCTION json.get_opt_string_array(
    in_json jsonb,
    in_default text[] DEFAULT NULL::text[],
    in_name text DEFAULT NULL::text)
  RETURNS text[] AS
$BODY$
declare
  v_array jsonb := json.get_opt_array(in_json, null, in_name);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_string_array(v_array);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
