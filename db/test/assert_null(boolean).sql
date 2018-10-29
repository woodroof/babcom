-- drop function test.assert_null(boolean);

create or replace function test.assert_null(in_expression boolean)
immutable
returns void as
$$
-- Проверяет, что выражение является null
begin
  if in_expression is not null then
    raise exception 'Assert_null failed.';
  end if;
end;
$$
language 'plpgsql';
