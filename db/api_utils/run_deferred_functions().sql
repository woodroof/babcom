-- Function: api_utils.run_deferred_functions()

-- DROP FUNCTION api_utils.run_deferred_functions();

CREATE OR REPLACE FUNCTION api_utils.run_deferred_functions()
  RETURNS void AS
$BODY$
begin
  -- TODO
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
