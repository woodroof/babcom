-- drop function test.assert_le(bigint, bigint);

create or replace function test.assert_le(in_expected bigint, in_actual bigint)
immutable
returns void as
$$
-- Проверяет, что ожидаемое значение меньше или равно реальному
begin
  if in_expected is null or in_actual is null or in_expected > in_actual then
    raise exception 'Assert_le failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language 'plpgsql';
