-- Function: data.get_object_id(text)

-- DROP FUNCTION data.get_object_id(text);

CREATE OR REPLACE FUNCTION data.get_object_id(in_object_code text)
  RETURNS integer AS
$BODY$
declare
  v_object_id integer;
begin
  assert in_object_code is not null;

  select id
  into v_object_id
  from data.objects
  where code = in_object_code;

  if v_object_id is null then
    perform utils.raise_invalid_input_param_value('Can''t find object "%s"', in_object_code);
  end if;

  return v_object_id;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
