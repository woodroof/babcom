-- Function: api_utils.create_ok_result(json, text)

-- DROP FUNCTION api_utils.create_ok_result(json, text);

CREATE OR REPLACE FUNCTION api_utils.create_ok_result(
    in_data json,
    in_message text DEFAULT NULL::text)
  RETURNS api.result AS
$BODY$
begin
  if in_message is null then
    return row(200, json_build_object('data', in_data));
  end if;

  return row(200, json_build_object('data', in_data, 'message', in_message));
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
