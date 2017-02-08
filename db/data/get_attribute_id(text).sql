-- Function: data.get_attribute_id(text)

-- DROP FUNCTION data.get_attribute_id(text);

CREATE OR REPLACE FUNCTION data.get_attribute_id(in_attribute_code text)
  RETURNS integer AS
$BODY$
declare
  v_attribute_id integer;
begin
  assert in_attribute_code is not null;

  select id
  into v_attribute_id
  from data.attributes
  where code = in_attribute_code;

  if v_attribute_id is null then
    perform utils.raise_invalid_input_param_value('Can''t find attribute "%s"', in_attribute_code);
  end if;

  return v_attribute_id;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
