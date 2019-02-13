-- drop function pp_utils.add_word_ending(text, bigint);

create or replace function pp_utils.add_word_ending(in_word text, in_count bigint)
returns text
immutable
as
$$
begin
  if in_count % 10 = 0 or in_count % 10 >= 5 or in_count > 10 and in_count < 20 then
    return in_word || 'ов';
  elsif in_count % 10 = 1 then
    return in_word;
  end if;

  return in_word || 'а';
end;
$$
language plpgsql;
