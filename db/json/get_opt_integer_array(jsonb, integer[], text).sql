-- Function: json.get_opt_integer_array(jsonb, integer[], text)

-- DROP FUNCTION json.get_opt_integer_array(jsonb, integer[], text);

CREATE OR REPLACE FUNCTION json.get_opt_integer_array(
    in_json jsonb,
    in_default integer[] DEFAULT NULL::integer[],
    in_name text DEFAULT NULL::text)
  RETURNS integer[] AS
$BODY$
declare
  v_array jsonb := json.get_opt_array(in_json, null, in_name);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_integer_array(v_array);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
