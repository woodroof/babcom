-- drop function pallas_project.vd_org_districts_influence(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_org_districts_influence(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_title_attr_id integer := data.get_attribute_id('title');
  v_ret_val text;
begin
  select E'\n' || string_agg(format('[%s](babcom:%s): %s', title, code, influence), E'\n')
  into v_ret_val
  from (
    select key code, json.get_string(data.get_attribute_value(key, v_title_attr_id)) title, json.get_integer(value) influence
    from jsonb_each(in_value)
    order by title) a;

  return v_ret_val; 
end;
$$
language plpgsql;
