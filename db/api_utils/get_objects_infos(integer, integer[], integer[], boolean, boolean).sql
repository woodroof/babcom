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
  v_template jsonb := data.get_param('template');
  v_object_infos data.object_info[];
  v_object_info data.object_info;
  v_attributes jsonb;
  v_actions jsonb;
  v_object_template jsonb;
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

    if in_get_actions then
      v_actions := data.get_object_actions(in_user_object_id, v_object_info.object_id);
    end if;

    v_ret_val :=
      v_ret_val || (
        jsonb_build_object(
          'code',
          v_object_info.object_code) ||
        case when v_attributes is not null then
          jsonb_build_object('attributes', v_attributes)
        else
          jsonb '{}'
        end ||
        case when (v_attributes is not null or v_actions is not null) and in_get_templates then
          jsonb_build_object('template', data.get_object_template(v_template, v_object_info.attribute_codes, v_actions))
        else
          jsonb '{}'
        end ||
        case when v_actions is not null then
          jsonb_build_object('actions', v_actions)
        else
          jsonb '{}'
        end);
  end loop;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;