-- Function: test.assert_not_null(bigint)

-- DROP FUNCTION test.assert_not_null(bigint);

CREATE OR REPLACE FUNCTION test.assert_not_null(in_expression bigint)
  RETURNS void AS
$BODY$
-- Проверяет, что выражение не является null
begin
  if in_expression is null then
    raise exception 'Assert_not_null failed.';
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
