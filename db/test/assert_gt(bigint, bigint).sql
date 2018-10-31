-- drop function test.assert_gt(bigint, bigint);

create or replace function test.assert_gt(in_expected bigint, in_actual bigint)
returns void
immutable
as
$$
-- Проверяет, что ожидаемое значение больше реального
begin
  if in_expected is null or in_actual is null or in_expected <= in_actual then
    raise exception 'Assert_gt failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language 'plpgsql';
