-- drop function data.attribute_change2jsonb(integer, jsonb, integer);

create or replace function data.attribute_change2jsonb(in_attribute_id integer, in_value jsonb, in_value_object_id integer)
returns jsonb
volatile
as
$$
declare
  v_result jsonb;
begin
  assert in_attribute_id is not null;

  v_result := jsonb_build_object('id', in_attribute_id, 'value_object_id', in_value_object_id);

  if in_value is not null then
    v_result := v_result || jsonb_build_object('value', in_value);
  end if;

  return v_result;
end;
$$
language plpgsql;
