-- Function: test.assert_no_throw(text)

-- DROP FUNCTION test.assert_no_throw(text);

CREATE OR REPLACE FUNCTION test.assert_no_throw(in_expression text)
  RETURNS void AS
$BODY$
-- Проверяет, что выражение не генерирует исключения
declare
  v_exception boolean := false;
  v_exception_message text;
  v_exception_call_stack text;
begin
  begin
    execute in_expression;
  exception when raise_exception then
    get stacked diagnostics
      v_exception_message = message_text,
      v_exception_call_stack = pg_exception_context;

    v_exception := true;
  end;

  if v_exception then
    raise exception E'Assert_no_throw failed.\nMessage: %.\nCall stack:\n%', v_exception_message, v_exception_call_stack;
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
