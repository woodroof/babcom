-- Function: test.assert_ne(jsonb, jsonb)

-- DROP FUNCTION test.assert_ne(jsonb, jsonb);

CREATE OR REPLACE FUNCTION test.assert_ne(
    in_expected jsonb,
    in_actual jsonb)
  RETURNS void AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
