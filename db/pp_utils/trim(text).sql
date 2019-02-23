-- drop function pp_utils.trim(text);

create or replace function pp_utils.trim(in_text text)
returns text
immutable
as
$$
begin
  return trim(in_text, E' \t\n');
end;
$$
language plpgsql;
