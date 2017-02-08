-- Function: api_utils.create_not_modified_result()

-- DROP FUNCTION api_utils.create_not_modified_result();

CREATE OR REPLACE FUNCTION api_utils.create_not_modified_result()
  RETURNS api.result AS
$BODY$
begin
  return row(304, null::json);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
