-- Function: data.get_array_param(text)

-- DROP FUNCTION data.get_array_param(text);

CREATE OR REPLACE FUNCTION data.get_array_param(in_code text)
  RETURNS jsonb AS
$BODY$
begin
  assert in_code is not null;

  return
    json.get_array(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not an array', in_code;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
