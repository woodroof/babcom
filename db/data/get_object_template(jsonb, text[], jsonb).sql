-- Function: data.get_object_template(jsonb, text[], jsonb)

-- DROP FUNCTION data.get_object_template(jsonb, text[], jsonb);

CREATE OR REPLACE FUNCTION data.get_object_template(
    in_template jsonb,
    in_object_attribute_codes text[],
    in_object_actions jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_template_groups jsonb := json.get_object_array(in_template, 'groups');
  v_group jsonb;
  v_object_groups jsonb := '[]';
  v_object_action_codes text[];

  v_attributes text[];
  v_group_attributes text[];
  v_attribute text;

  v_actions text[];
  v_group_actions text[];
  v_action text;
begin
  assert in_object_attribute_codes is not null or in_object_actions is not null;

  for v_group in
    select * from jsonb_array_elements(v_template_groups)
  loop
    v_group_attributes := null;
    v_group_actions := null;

    if in_object_attribute_codes is not null then
      v_attributes := json.get_opt_string_array(v_group, null, 'attributes');
      if v_attributes is not null then
        foreach v_attribute in array v_attributes loop
          if v_attribute = any(in_object_attribute_codes) then
            v_group_attributes := v_group_attributes || array[v_attribute];
          end if;
        end loop;
      end if;
    end if;

    if in_object_actions is not null then
      select array_agg(value)
      into v_object_action_codes
      from jsonb_object_keys(in_object_actions) s(value);

      v_actions := json.get_opt_string_array(v_group, null, 'actions');
      if v_actions is not null then
        foreach v_action in array v_actions loop
          if v_action = any(v_object_action_codes) then
            v_group_actions := v_group_actions || array[v_action];
          end if;
        end loop;
      end if;
    end if;

    if v_group_attributes is not null or v_group_actions is not null then
      v_object_groups :=
        v_object_groups ||
        (
          case when v_group_attributes is not null then
            jsonb_build_object('attributes', v_group_attributes)
          else
            jsonb '{}'
          end ||
          case when v_group_actions is not null then
            jsonb_build_object('actions', v_group_actions)
          else
            jsonb '{}'
          end ||
          case when v_group ? 'name' then
            jsonb_build_object('name', json.get_string(v_group, 'name'))
          else
            jsonb '{}'
          end);
    end if;
  end loop;

  return jsonb_build_object('groups', v_object_groups);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
