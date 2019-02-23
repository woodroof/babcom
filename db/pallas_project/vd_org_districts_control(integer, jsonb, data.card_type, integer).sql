-- drop function pallas_project.vd_org_districts_control(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_org_districts_control(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_title_attr_id integer := data.get_attribute_id('title');
  v_districts text[] := json.get_string_array(in_value);
  v_description text;
begin
  if coalesce(array_length(v_districts, 1), 0) = 0 then
    return 'нет';
  end if;

  select string_agg(format('[%s](babcom:%s)', title, code), ', ')
  into v_description
  from (
    select code, json.get_string(data.get_attribute_value(id, v_title_attr_id, in_actor_id)) title
    from (
      select value code, data.get_object_id(value) id
      from unnest(v_districts) a(value)) d
    order by title) t;

  return v_description; 
end;
$$
language plpgsql;
