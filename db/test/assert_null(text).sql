-- Function: test.assert_null(text)

-- DROP FUNCTION test.assert_null(text);

CREATE OR REPLACE FUNCTION test.assert_null(in_expression text)
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
