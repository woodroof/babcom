-- drop function data.get_attribute_code(integer);

create or replace function data.get_attribute_code(in_attribute_id integer)
returns text
stable
as
$$
declare
  v_attribute_code text;
begin
  assert in_attribute_id is not null;

  select code
  into v_attribute_code
  from data.attributes
  where id = in_attribute_id;

  if v_attribute_code is null then
    raise exception 'Can''t find attribute "%"', in_attribute_id;
  end if;

  return v_attribute_code;
end;
$$
language 'plpgsql';
