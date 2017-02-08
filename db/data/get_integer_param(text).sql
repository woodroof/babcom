-- Function: data.get_integer_param(text)

-- DROP FUNCTION data.get_integer_param(text);

CREATE OR REPLACE FUNCTION data.get_integer_param(in_code text)
  RETURNS integer AS
$BODY$
begin
  assert in_code is not null;

  return
    json.get_integer(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not an integer', in_code;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
