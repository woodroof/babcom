-- Function: json.get_opt_bool(json, boolean, text)

-- DROP FUNCTION json.get_opt_bool(json, boolean, text);

CREATE OR REPLACE FUNCTION json.get_opt_bool(
    in_json json,
    in_default boolean DEFAULT NULL::boolean,
    in_name text DEFAULT NULL::text)
  RETURNS boolean AS
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

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'boolean' then
    raise exception 'Attribute "%" is not a boolean', in_name;
  end if;

  return v_param;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
