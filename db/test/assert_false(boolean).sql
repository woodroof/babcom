-- Function: test.assert_false(boolean)

-- DROP FUNCTION test.assert_false(boolean);

CREATE OR REPLACE FUNCTION test.assert_false(in_expression boolean)
  RETURNS void AS
$BODY$
-- Проверяет, что выражение ложно
begin
  if in_expression is null or in_expression = true then
    raise exception 'Assert_false failed.';
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
