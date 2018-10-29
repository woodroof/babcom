-- drop function error.raise_invalid_input_param_value(text, text, text);

create or replace function error.raise_invalid_input_param_value(in_format text, in_param1 text, in_param2 text)
immutable
returns bigint as
$$

begin
  assert in_format is not null;
  assert in_param1 is not null;
  assert in_param2 is not null;

  raise '%', format(in_format, in_param1, in_param2) using errcode = 'invalid_parameter_value';
end;

$$
language 'plpgsql';
