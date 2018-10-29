-- drop function test.assert_true(boolean);

create or replace function test.assert_true(in_expression boolean)
immutable
returns void as
$$
-- Проверяет, что выражение истинно
begin
  if in_expression is null or in_expression = false then
    raise exception 'Assert_true failed.';
  end if;
end;
$$
language 'plpgsql';
