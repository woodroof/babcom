-- Function: data.is_system_attribute(integer)

-- DROP FUNCTION data.is_system_attribute(integer);

CREATE OR REPLACE FUNCTION data.is_system_attribute(in_attribute_id integer)
  RETURNS boolean AS
$BODY$
declare
  v_ret_val boolean;
begin
  select type = 'SYSTEM'
  into v_ret_val
  from data.attributes
  where id = in_attribute_id;

  if v_ret_val is null then
    raise exception 'Attribute with id % not found', in_attribute_id;
  end if;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
