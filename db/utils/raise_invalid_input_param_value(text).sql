-- Function: utils.raise_invalid_input_param_value(text)

-- DROP FUNCTION utils.raise_invalid_input_param_value(text);

CREATE OR REPLACE FUNCTION utils.raise_invalid_input_param_value(in_message text)
  RETURNS bigint AS
$BODY$
begin
  assert in_message is not null;

  raise '%', in_message using errcode = 'invalid_parameter_value';
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
