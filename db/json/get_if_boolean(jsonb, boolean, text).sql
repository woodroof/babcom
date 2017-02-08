-- Function: json.get_if_boolean(jsonb, boolean, text)

-- DROP FUNCTION json.get_if_boolean(jsonb, boolean, text);

CREATE OR REPLACE FUNCTION json.get_if_boolean(
    in_json jsonb,
    in_default boolean DEFAULT NULL::boolean,
    in_name text DEFAULT NULL::text)
  RETURNS boolean AS
$BODY$
declare
  v_param jsonb;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  if jsonb_typeof(v_param) = 'boolean' then
    return v_param;
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
