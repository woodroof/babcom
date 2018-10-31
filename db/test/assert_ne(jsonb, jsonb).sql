-- drop function test.assert_ne(jsonb, jsonb);

create or replace function test.assert_ne(in_expected jsonb, in_actual jsonb)
returns void
immutable
as
$$
-- Проверяет, что реальное значение не равно ожидаемому
-- Если оба значения null, то это считается равенством
-- Если ожидаемое значение null, то реальное не должно быть null
begin
  if
    (
      in_expected is null and
      in_actual is null
    ) or
    (
      in_expected is not null and
      in_actual is not null and
      in_expected = in_actual
    )
  then
    raise exception 'Assert_ne failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language 'plpgsql';
