-- drop function pp_utils.format_money(bigint);

create or replace function pp_utils.format_money(in_value bigint)
returns text
immutable
as
$$
begin
  if in_value < 0 then
    return '−UN$' || abs(in_value);
  end if;

  return 'UN$' || in_value;
end;
$$
language plpgsql;
