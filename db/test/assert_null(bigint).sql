-- drop function test.assert_null(bigint);

create or replace function test.assert_null(in_expression bigint)
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
