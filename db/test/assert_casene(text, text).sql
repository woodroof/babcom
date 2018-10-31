-- drop function test.assert_casene(text, text);

create or replace function test.assert_casene(in_expected text, in_actual text)
returns void
immutable
as
$$
-- Проверяет, что реальное значение не равно ожидаемому без учёта регистра
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
      lower(in_expected) = lower(in_actual)
    )
  then
    raise exception 'Assert_casene failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$$
language 'plpgsql';
