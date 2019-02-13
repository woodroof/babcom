-- drop function data.get_integer_array_param(text);

create or replace function data.get_integer_array_param(in_code text)
returns integer[]
stable
as
$$
begin
  assert in_code is not null;

  return
    json.get_integer_array(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not an integer array', in_code;
end;
$$
language plpgsql;
