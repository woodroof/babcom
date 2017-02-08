-- Function: data.is_object_visible(integer, integer)

-- DROP FUNCTION data.is_object_visible(integer, integer);

CREATE OR REPLACE FUNCTION data.is_object_visible(
    in_user_object_id integer,
    in_object_id integer)
  RETURNS boolean AS
$BODY$
begin
  assert in_user_object_id is not null;
  assert in_object_id is not null;

  return json.get_boolean(
    data.get_attribute_value(
      in_user_object_id,
      in_object_id,
      data.get_attribute_id('system_is_visible')));
exception when invalid_parameter_value then
  return false;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
