-- Function: test.assert_null(boolean)

-- DROP FUNCTION test.assert_null(boolean);

CREATE OR REPLACE FUNCTION test.assert_null(in_expression boolean)
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
