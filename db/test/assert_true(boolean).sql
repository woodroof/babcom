-- Function: test.assert_true(boolean)

-- DROP FUNCTION test.assert_true(boolean);

CREATE OR REPLACE FUNCTION test.assert_true(in_expression boolean)
  RETURNS void AS
$BODY$
-- Проверяет, что выражение истинно
begin
  if in_expression is null or in_expression = false then
    raise exception 'Assert_true failed.';
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
