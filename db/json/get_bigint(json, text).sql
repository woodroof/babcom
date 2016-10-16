-- Function: json.get_bigint(json, text)

-- DROP FUNCTION json.get_bigint(json, text);

CREATE OR REPLACE FUNCTION json.get_bigint(
    in_json json,
    in_name text DEFAULT NULL::text)
  RETURNS bigint AS
$BODY$
declare
  v_param json;
  v_param_type text;
  v_retval bigint;
begin
  if in_name is not null then
    v_param := in_json->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := json_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      raise exception 'Attribute "%" was not found', in_name;
    end if;
    if v_param_type != 'number' then
      raise exception 'Attribute "%" is not a number', in_name;
    end if;
  elseif v_param_type is null or v_param_type != 'number' then
    raise exception 'Json is not a number';
  end if;

  begin
    v_retval := v_param;
  exception when others then
    if in_name is not null then
      raise exception 'Attribute "%" is not a bigint', in_name;
    else
      raise exception 'Json is not a bigint';
    end if;
  end;

  return v_retval;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
