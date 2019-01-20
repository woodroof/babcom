-- drop function test_project.next_code(text);

create or replace function test_project.next_code(in_code text)
returns text
immutable
as
$$
declare
  v_prefix text := trim(trailing '0123456789' from in_code);
  v_suffix integer := substring(in_code from char_length(v_prefix) + 1)::integer;
begin
  return v_prefix || (v_suffix + 1)::text;
end;
$$
language plpgsql;
