-- drop function data.is_hidden_attribute(integer);

create or replace function data.is_hidden_attribute(in_attribute_id integer)
returns boolean
stable
as
$$
declare
  v_ret_val boolean;
begin
  select type = 'hidden'
  into v_ret_val
  from data.attributes
  where id = in_attribute_id;

  if v_ret_val is null then
    raise exception 'Attribute % was not found', in_attribute_id;
  end if;

  return v_ret_val;
end;
$$
language plpgsql;
