-- Function: test.assert_caseeq(text, text)

-- DROP FUNCTION test.assert_caseeq(text, text);

CREATE OR REPLACE FUNCTION test.assert_caseeq(
    in_expected text,
    in_actual text)
  RETURNS void AS
$BODY$
-- Проверяет, что реальное значение равно ожидаемому без учёта регистра
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
        lower(in_expected) != lower(in_actual)
      )
    )
  then
    raise exception 'Assert_caseeq failed. Expected: %. Actual: %.', in_expected, in_actual;
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
