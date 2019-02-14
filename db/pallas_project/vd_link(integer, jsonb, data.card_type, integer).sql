-- drop function pallas_project.vd_link(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_link(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_code text := json.get_string(in_value);
  v_title text := data.get_string_opt(data.get_attribute_value(v_code, 'title', in_actor_id), '???');
begin
  assert in_actor_id is not null;

  return format('[%s](babcom:%s)', v_title, v_code);
end;
$$
language plpgsql;
