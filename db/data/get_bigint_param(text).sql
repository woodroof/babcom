-- Function: data.get_bigint_param(text)

-- DROP FUNCTION data.get_bigint_param(text);

CREATE OR REPLACE FUNCTION data.get_bigint_param(in_code text)
  RETURNS bigint AS
$BODY$
begin
  assert in_code is not null;

  return
    json.get_bigint(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not a bigint', in_code;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
