-- Function: api_utils.get_objects_infos(integer, integer[], integer[], boolean, boolean)

-- DROP FUNCTION api_utils.get_objects_infos(integer, integer[], integer[], boolean, boolean);

CREATE OR REPLACE FUNCTION api_utils.get_objects_infos(
    in_user_object_id integer,
    in_object_ids integer[],
    in_attribute_ids integer[],
    in_get_actions boolean,
    in_get_templates boolean)
  RETURNS jsonb AS
$BODY$
declare
  v_object_infos data.object_info[];
  v_object_info data.object_info;
  v_attributes jsonb;
  v_ret_val jsonb := '[]';
begin
  assert in_user_object_id is not null;
  assert in_object_ids is not null;
  assert in_get_actions is not null;
  assert in_get_templates is not null;

  v_object_infos := data.get_object_infos(in_user_object_id, in_object_ids, in_attribute_ids, in_get_actions, in_get_templates);

  foreach v_object_info in array v_object_infos loop
    v_attributes :=
      api_utils.build_attributes(
        v_object_info.attribute_codes,
        v_object_info.attribute_names,
        v_object_info.attribute_values,
        v_object_info.attribute_value_descriptions,
        v_object_info.attribute_types);
    v_ret_val :=
      v_ret_val || (
        jsonb_build_object(
          'code',
          v_object_info.object_code) ||
        case when v_attributes is not null then jsonb_build_object('attributes', v_attributes) else jsonb '{}' end);
    -- TODO: add actions, templates
  end loop;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
