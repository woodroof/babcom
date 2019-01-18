-- drop function data.get_class_id(text);

create or replace function data.get_class_id(in_class_code text)
returns integer
stable
as
$$
declare
  v_class_id integer;
begin
  assert in_class_code is not null;

  select id
  into v_class_id
  from data.objects
  where
    code = in_class_code and
    type = 'class';

  if v_class_id is null then
    raise exception 'Can''t find class "%"', in_class_code;
  end if;

  return v_class_id;
end;
$$
language 'plpgsql';
