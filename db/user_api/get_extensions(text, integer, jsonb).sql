-- Function: user_api.get_extensions(text, integer, jsonb)

-- DROP FUNCTION user_api.get_extensions(text, integer, jsonb);

CREATE OR REPLACE FUNCTION user_api.get_extensions(
    in_client text,
    in_login_id integer,
    in_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_extensions json;
begin
  select coalesce(json_agg(f.code), json '[]')
  into v_extensions
  from (
    select code
    from data.extensions
    order by code
  ) f;

  return api_utils.create_ok_result(v_extensions);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
