-- Function: test.assert_null(bigint)

-- DROP FUNCTION test.assert_null(bigint);

CREATE OR REPLACE FUNCTION test.assert_null(in_expression bigint)
  RETURNS void AS
$BODY$
-- Проверяет, что выражение является null
begin
  if in_expression is not null then
    raise exception 'Assert_null failed.';
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
