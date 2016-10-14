-- Function: test.assert_eq(text, text)

-- DROP FUNCTION test.assert_eq(text, text);

CREATE OR REPLACE FUNCTION test.assert_eq(
    in_expected text,
    in_actual text)
  RETURNS void AS
$BODY$
-- Проверяет, что реальное значение равно ожидаемому
-- Если оба значения null, то это считается равенством
-- Если ожидаемое значение null, то и реальное должно быть null
begin
  if
    (
      in_expected is null and
      in_actual is not null
    ) or
    (
      in_expected is not null and
      (
        in_actual is null or
        in_expected != in_actual
      )
    )
  then
    raise exception 'Assert_eq failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
