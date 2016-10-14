-- Function: test.fail(text)

-- DROP FUNCTION test.fail(text);

CREATE OR REPLACE FUNCTION test.fail(in_description text DEFAULT NULL::text)
  RETURNS void AS
$BODY$
-- Всегда генерирует исключение
begin
  if in_description is not null then
    raise exception 'Fail. Description: %', in_description;
  else
    raise exception 'Fail.';
  end if;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
