-- Function: data.get_string_param(text)

-- DROP FUNCTION data.get_string_param(text);

CREATE OR REPLACE FUNCTION data.get_string_param(in_code text)
  RETURNS text AS
$BODY$
begin
  assert in_code is not null;

  return
    json.get_string(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not a string', in_code;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
