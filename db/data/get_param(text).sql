-- Function: data.get_param(text)

-- DROP FUNCTION data.get_param(text);

CREATE OR REPLACE FUNCTION data.get_param(in_code text)
  RETURNS jsonb AS
$BODY$
declare
  v_value jsonb;
begin
  assert in_code is not null;

  select value
  into v_value
  from data.params
  where code = in_code;

  if v_value is null then
    raise exception 'Param "%" was not found', in_code;
  end if;

  return v_value;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
