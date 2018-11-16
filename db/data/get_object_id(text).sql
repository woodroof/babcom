-- drop function data.get_object_id(text);

create or replace function data.get_object_id(in_object_code text)
returns integer
stable
as
$$
declare
  v_object_id integer;
begin
  assert in_object_code is not null;

  select id
  into v_object_id
  from data.objects
  where code = in_object_code;

  if v_object_id is null then
    perform error.raise_invalid_input_param_value('Can''t find object "%s"', in_object_code);
  end if;

  return v_object_id;
end;
$$
language 'plpgsql';
