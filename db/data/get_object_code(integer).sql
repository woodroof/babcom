-- drop function data.get_object_code(integer);

create or replace function data.get_object_code(in_object_id integer)
returns text
stable
as
$$
declare
  v_object_code text;
begin
  assert in_object_id is not null;

  select code
  into v_object_code
  from data.objects
  where id = in_object_id;

  if v_object_code is null then
    perform error.raise_invalid_input_param_value('Can''t find object %s', in_object_id);
  end if;

  return v_object_code;
end;
$$
language 'plpgsql';
