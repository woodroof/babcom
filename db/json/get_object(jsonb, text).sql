-- Function: json.get_object(jsonb, text)

-- DROP FUNCTION json.get_object(jsonb, text);

CREATE OR REPLACE FUNCTION json.get_object(
    in_json jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS jsonb AS
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

  v_param_type := jsonb_typeof(v_param);

  if v_param_type is null then
    raise exception 'Attribute "%" was not found', in_name;
  end if;
  if v_param_type != 'object' then
    raise exception 'Attribute "%" is not an object', in_name;
  end if;
  return v_param;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
