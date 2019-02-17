-- drop function data.get_attribute_value(text, integer, integer);

create or replace function data.get_attribute_value(in_object_code text, in_attribute_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
begin
  return data.get_attribute_value(data.get_object_id(in_object_code), in_attribute_id, in_actor_id);
end;
$$
language plpgsql;
