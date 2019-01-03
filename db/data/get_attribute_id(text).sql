-- drop function data.get_attribute_id(text);

create or replace function data.get_attribute_id(in_attribute_code text)
returns integer
stable
as
$$
declare
  v_attribute_id integer;
begin
  assert in_attribute_code is not null;

  select id
  into v_attribute_id
  from data.attributes
  where code = in_attribute_code;

  if v_attribute_id is null then
    raise exception 'Can''t find attribute "%"', in_attribute_code;
  end if;

  return v_attribute_id;
end;
$$
language 'plpgsql';
