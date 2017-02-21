-- Function: api_utils.get_objects(text, integer, jsonb)

-- DROP FUNCTION api_utils.get_objects(text, integer, jsonb);

CREATE OR REPLACE FUNCTION api_utils.get_objects(
    in_client text,
    in_user_object_id integer,
    in_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_object_codes text[];

  v_filter_result api_utils.objects_process_result;
  v_sort_result api_utils.objects_process_result;

  v_attributes text[];
  v_attribute_ids integer[];
  v_attributes_to_fill_ids integer[];

  v_objects jsonb;
  v_etag text;
  v_if_non_match text;
begin
  assert in_client is not null;
  assert in_user_object_id is not null;
  assert in_params is not null;

  if in_params ? 'object_codes' then
    v_object_codes := json.get_string_array(in_params, 'object_codes');
  else
    v_object_codes := api_utils.get_object_codes_info_from_attribute(in_user_object_id, in_params);
  end if;

  if v_object_codes is not null then
    v_filter_result := api_utils.get_filtered_object_ids(in_user_object_id, v_object_codes, in_params);
  end if;

  if v_filter_result is null or v_filter_result.object_ids is null then
    v_etag := encode(pgcrypto.digest('', 'sha256'), 'base64');

    v_if_non_match := json.get_opt_string(in_params, null, 'if_non_match');
    if
      v_if_non_match is not null and
      v_if_non_match = v_etag
    then
      return api_utils.create_not_modified_result();
    end if;

    return api_utils.create_ok_result(
      json_build_object(
        'etag', v_etag));
  end if;

  v_sort_result := api_utils.get_sorted_object_ids(in_user_object_id, v_filter_result.object_ids, v_filter_result.filled_attributes_ids, in_params);

  v_sort_result.object_ids := api_utils.limit_object_ids(v_sort_result.object_ids, in_params);

  if in_params ? 'attributes' then
    v_attributes := json.get_string_array(in_params, 'attributes');

    select array_agg(id)
    into v_attribute_ids
    from data.attributes
    where code = any(v_attributes);

    select array_agg(id)
    into v_attributes_to_fill_ids
    from data.attributes
    where
      id = any(v_attribute_ids) and
      id != any(v_sort_result.filled_attributes_ids);
  else
    select array_agg(id)
    into v_attribute_ids
    from data.attributes
    where type in ('NORMAL', 'HIDDEN');

    select array_agg(id)
    into v_attributes_to_fill_ids
    from data.attributes
    where
      id = any(v_attribute_ids) and
      id != any(v_sort_result.filled_attributes_ids);
  end if;

  if v_attributes_to_fill_ids is not null then
    perform data.fill_attribute_values(in_user_object_id, v_sort_result.object_ids, v_attributes_to_fill_ids);
  end if;

  v_objects :=
    api_utils.get_objects_infos(
      in_user_object_id,
      v_sort_result.object_ids,
      v_attribute_ids,
      json.get_opt_boolean(in_params, true, 'get_actions'),
      json.get_opt_boolean(in_params, true, 'get_templates'));

  v_etag := encode(pgcrypto.digest(v_objects::text, 'sha256'), 'base64');

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
