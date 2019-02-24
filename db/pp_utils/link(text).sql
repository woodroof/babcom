-- drop function pp_utils.link(text);

create or replace function pp_utils.link(in_code text)
returns text
stable
as
$$
declare
  v_title text := json.get_string_opt(data.get_attribute_value(data.get_object_id(in_code), 'title'), '???');
begin
  return format('[%s](babcom:%s)', v_title, in_code);
end;
$$
language plpgsql;
