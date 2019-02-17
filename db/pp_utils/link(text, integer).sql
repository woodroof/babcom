-- drop function pp_utils.link(text, integer);

create or replace function pp_utils.link(in_code text, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_title text := json.get_string_opt(data.get_attribute_value(data.get_object_id(in_code), 'title', in_actor_id), '???');
begin
  assert in_actor_id is not null;

  return format('[%s](babcom:%s)', v_title, in_code);
end;
$$
language plpgsql;
