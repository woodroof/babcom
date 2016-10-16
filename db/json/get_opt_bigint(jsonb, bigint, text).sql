-- Function: json.get_opt_bigint(jsonb, bigint, text)

-- DROP FUNCTION json.get_opt_bigint(jsonb, bigint, text);

CREATE OR REPLACE FUNCTION json.get_opt_bigint(
    in_json jsonb,
    in_default bigint DEFAULT NULL::bigint,
    in_name text DEFAULT NULL::text)
  RETURNS bigint AS
$BODY$
declare
  v_param jsonb;
  v_param_type text;
  v_retval bigint;
begin
  if in_name is not null then
    v_param := in_json->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := jsonb_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'number' then
    if in_name is not null then
      raise exception 'Attribute "%" is not a number', in_name;
    else
      raise exception 'Json is not a number';
    end if;
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
