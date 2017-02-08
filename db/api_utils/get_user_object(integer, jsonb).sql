-- Function: api_utils.get_user_object(integer, jsonb)

-- DROP FUNCTION api_utils.get_user_object(integer, jsonb);

CREATE OR REPLACE FUNCTION api_utils.get_user_object(
    in_login_id integer,
    in_params jsonb)
  RETURNS integer AS
$BODY$
declare
  v_user_object_code text := json.get_string(in_params, 'user_object_code');
  v_object_id integer;
begin
  select o.id
  into v_object_id
  from data.login_objects lo
  join data.objects o on
    lo.login_id = in_login_id and
    o.id = lo.object_id and
    o.code = v_user_object_code;

  return v_object_id;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
