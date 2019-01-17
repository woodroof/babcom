-- drop function data.attribute_change2jsonb(integer, integer, jsonb);

create or replace function data.attribute_change2jsonb(in_attribute_id integer, in_value_object_id integer, in_value jsonb)
returns jsonb
volatile
as
$$
declare
  v_result jsonb;
begin
  v_result := jsonb_build_object('id', in_attribute_id);
  if in_value_object_id is not null then 
    v_result := v_result || jsonb_build_object('value_object_id', in_value_object_id);
  end if;
  if in_value is not null then
    v_result := v_result || jsonb_build_object('value', in_value);
  end if;
  return v_result;
end;
$$
language 'plpgsql';
