-- drop function test.fail(text);

create or replace function test.fail(in_description text DEFAULT NULL::text)
immutable
returns void as
$$
-- Всегда генерирует исключение
begin
  if in_description is not null then
    raise exception 'Fail. Description: %', in_description;
  else
    raise exception 'Fail.';
  end if;
end;
$$
language 'plpgsql';
