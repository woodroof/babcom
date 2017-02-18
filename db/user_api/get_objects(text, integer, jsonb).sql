-- Function: user_api.get_objects(text, integer, jsonb)

-- DROP FUNCTION user_api.get_objects(text, integer, jsonb);

CREATE OR REPLACE FUNCTION user_api.get_objects(
    in_client text,
    in_login_id integer,
    in_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_user_object_id integer := api_utils.get_user_object(in_login_id, in_params);
begin
  if v_user_object_id is null then
    return api_utils.create_forbidden_result('Invalid user object');
  end if;

  return api_utils.get_objects(in_client, v_user_object_id, in_params);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
