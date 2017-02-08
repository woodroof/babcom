-- Function: api_utils.create_internal_server_error_result(text)

-- DROP FUNCTION api_utils.create_internal_server_error_result(text);

CREATE OR REPLACE FUNCTION api_utils.create_internal_server_error_result(in_message text)
  RETURNS api.result AS
$BODY$
begin
  assert in_message is not null;

  return row(500, json_build_object('message', in_message));
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
