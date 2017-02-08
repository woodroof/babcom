-- Function: utils.raise_invalid_input_param_value(text, text)

-- DROP FUNCTION utils.raise_invalid_input_param_value(text, text);

CREATE OR REPLACE FUNCTION utils.raise_invalid_input_param_value(
    in_format text,
    in_param text)
  RETURNS bigint AS
$BODY$
begin
  assert in_format is not null;
  assert in_param is not null;

  raise '%', format(in_format, in_param) using errcode = 'invalid_parameter_value';
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
