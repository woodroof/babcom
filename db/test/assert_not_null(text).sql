-- drop function test.assert_not_null(text);

create or replace function test.assert_not_null(in_expression text)
immutable
returns void as
$$
-- Проверяет, что выражение не является null
begin
  if in_expression is null then
    raise exception 'Assert_not_null failed.';
  end if;
end;
$$
language 'plpgsql';
