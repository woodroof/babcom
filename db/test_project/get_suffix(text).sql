-- drop function test_project.get_suffix(text);

create or replace function test_project.get_suffix(in_code text)
returns integer
immutable
as
$$
declare
  v_prefix text := trim(trailing '0123456789' from in_code);
begin
  return substring(in_code from char_length(v_prefix) + 1)::integer;
end;
$$
language plpgsql;
