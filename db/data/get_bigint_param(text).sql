-- drop function data.get_bigint_param(text);

create or replace function data.get_bigint_param(in_code text)
returns bigint
stable
as
$$
begin
  assert in_code is not null;

  return
    json.get_bigint(
      data.get_param(in_code));
exception when invalid_parameter_value then
  raise exception 'Param "%" is not a bigint', in_code;
end;
$$
language plpgsql;
