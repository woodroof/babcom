-- drop function pp_utils.format_date(timestamp with time zone);

create or replace function pp_utils.format_date(in_time timestamp with time zone)
returns text
stable
as
$$
begin
  return format(to_char(in_time, 'DD.MM.%s HH24:MI:SS'), data.get_integer_param('year'));
end;
$$
language plpgsql;
