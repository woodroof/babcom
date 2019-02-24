-- drop function pp_utils.link(integer);

create or replace function pp_utils.link(in_object_id integer)
returns text
stable
as
$$
declare
  v_title text := json.get_string_opt(data.get_attribute_value(in_object_id, 'title'), '???');
begin
  return format('[%s](babcom:%s)', v_title, data.get_object_code(in_object_id));
end;
$$
language plpgsql;
