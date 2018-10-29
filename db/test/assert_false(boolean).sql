-- drop function test.assert_false(boolean);

create or replace function test.assert_false(in_expression boolean)
immutable
returns void as
$$
-- Проверяет, что выражение ложно
begin
  if in_expression is null or in_expression = true then
    raise exception 'Assert_false failed.';
  end if;
end;
$$
language 'plpgsql';
