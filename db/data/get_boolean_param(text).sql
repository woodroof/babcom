-- Function: data.get_boolean_param(text)

-- DROP FUNCTION data.get_boolean_param(text);

CREATE OR REPLACE FUNCTION data.get_boolean_param(in_code text)
  RETURNS boolean AS
$BODY$
begin
  assert in_code is not null;

  return
    json.get_boolean(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not a boolean', in_code;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
