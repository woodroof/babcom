-- drop function pallas_project.un_rating_to_coins(integer);

create or replace function pallas_project.un_rating_to_coins(in_un_rating integer)
returns integer
immutable
as
$$
begin
  if in_un_rating < 100 then
    return 10;
  elsif in_un_rating < 200 then
    return 29;
  elsif in_un_rating < 300 then
    return 34;
  elsif in_un_rating < 400 then
    return 50;
  elsif in_un_rating < 500 then
    return 60;
  elsif in_un_rating < 600 then
    return 70;
  else
    return 80;
  end if;
end;
$$
language plpgsql;
