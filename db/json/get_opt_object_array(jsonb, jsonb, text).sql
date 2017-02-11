-- Function: json.get_opt_object_array(jsonb, jsonb, text)

-- DROP FUNCTION json.get_opt_object_array(jsonb, jsonb, text);

CREATE OR REPLACE FUNCTION json.get_opt_object_array(
    in_json jsonb,
    in_default jsonb DEFAULT NULL::jsonb,
    in_name text DEFAULT NULL::text)
  RETURNS jsonb AS
$BODY$
declare
  v_default_type text;
  v_array jsonb;
begin
  if in_default is not null then
    begin
      perform json.get_object_array(in_default);
    exception when invalid_parameter_value then
      raise exception 'Default value "%" is not an object array', in_default::text;
    end;
  end if;

  v_array := json.get_opt_array(in_json, null, in_name);
  if v_array is null then
    return in_default;
  end if;

  return json.get_object_array(v_array);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
