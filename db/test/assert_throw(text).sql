-- Function: test.assert_throw(text)

-- DROP FUNCTION test.assert_throw(text);

CREATE OR REPLACE FUNCTION test.assert_throw(in_expression text)
  RETURNS void AS
$BODY$
-- Проверяет, что выражение генерирует исключение
declare
  v_exception boolean := false;
begin
  begin
    execute in_expression;
  exception when raise_exception then
    v_exception := true;
  end;

  if not v_exception then
    raise exception 'Assert_throw failed.';
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
