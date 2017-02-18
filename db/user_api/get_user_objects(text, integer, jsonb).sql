-- Function: user_api.get_user_objects(text, integer, jsonb)

-- DROP FUNCTION user_api.get_user_objects(text, integer, jsonb);

CREATE OR REPLACE FUNCTION user_api.get_user_objects(
    in_client text,
    in_login_id integer,
    in_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_name_attribute_id integer;
  v_name_attribute_name text;
  v_objects jsonb;
  v_etag text;
  v_if_non_match text;
begin
  perform data.fill_attribute_values(object_id, array[object_id], array[v_name_attribute_id])
  from data.login_objects
  where login_id = in_login_id;

  select id, name
  into v_name_attribute_id, v_name_attribute_name
  from data.attributes
  where
    code = 'name' and
    type = 'NORMAL';

  if v_name_attribute_id is null then
    raise exception 'Can''t find normal attribute "name"';
  end if;

  select
    jsonb_agg(
      jsonb_build_object(
        'code',
        code) ||
      case when value is not null then
        jsonb_build_object(
          'attributes',
          jsonb_build_object(
            'name',
            jsonb_build_object(
              'name',
              v_name_attribute_name,
              'value',
              value)))
      else jsonb '{}' end)
  into v_objects
  from (
    select o.code, data.get_attribute_value(o.id, o.id, v_name_attribute_id) as value
    from data.login_objects lo
    join data.objects o on
      login_id = in_login_id and
      o.id = lo.object_id
    order by value, code
  ) v;

  v_etag := encode(pgcrypto.digest(coalesce(v_objects::text, ''), 'sha256'), 'base64');

  v_if_non_match := json.get_opt_string(in_params, null, 'if_non_match');
  if
    v_if_non_match is not null and
    v_if_non_match = v_etag
  then
    return api_utils.create_not_modified_result();
  end if;

  return api_utils.create_ok_result(
    json_build_object(
      'etag', v_etag,
      'objects', v_objects));
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
