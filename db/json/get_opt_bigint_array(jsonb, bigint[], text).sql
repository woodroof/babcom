-- Function: json.get_opt_bigint_array(jsonb, bigint[], text)

-- DROP FUNCTION json.get_opt_bigint_array(jsonb, bigint[], text);

CREATE OR REPLACE FUNCTION json.get_opt_bigint_array(
    in_json jsonb,
    in_default bigint[] DEFAULT NULL::bigint[],
    in_name text DEFAULT NULL::text)
  RETURNS bigint[] AS
$BODY$
declare
  v_array jsonb := json.get_opt_array(in_json, null, in_name);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_bigint_array(v_array);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;