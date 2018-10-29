-- drop function error.raise_invalid_input_param_value(text);

create or replace function error.raise_invalid_input_param_value(in_message text)
immutable
returns bigint as
$$

begin
  assert in_message is not null;

  raise '%', in_message using errcode = 'invalid_parameter_value';
end;

$$
language 'plpgsql';
