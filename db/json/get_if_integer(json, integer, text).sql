-- Function: json.get_if_integer(json, integer, text)

-- DROP FUNCTION json.get_if_integer(json, integer, text);

CREATE OR REPLACE FUNCTION json.get_if_integer(
    in_json json,
    in_default integer DEFAULT NULL::integer,
    in_name text DEFAULT NULL::text)
  RETURNS integer AS
$BODY$
declare
  v_param json;
  v_param_type text;
  v_ret_val integer;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  if json_typeof(v_param) = 'number' then
    begin
      v_ret_val := v_param;
      return v_ret_val;
    exception when others then
    end;
  end if;

  return in_default;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
