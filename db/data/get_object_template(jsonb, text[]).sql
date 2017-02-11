-- Function: data.get_object_template(jsonb, text[])

-- DROP FUNCTION data.get_object_template(jsonb, text[]);

CREATE OR REPLACE FUNCTION data.get_object_template(
    in_template jsonb,
    in_object_attribute_codes text[])
  RETURNS jsonb AS
$BODY$
declare
  v_template_groups jsonb := json.get_object_array(in_template, 'groups');
  v_group jsonb;
  v_attributes text[];
  v_object_groups jsonb := '[]';
  v_attribute text;
  v_group_attributes text[];
begin
  assert in_object_attribute_codes is not null;

  for v_group in
    select * from jsonb_array_elements(v_template_groups)
  loop
    v_attributes := json.get_opt_string_array(v_group, null, 'attributes');
    if v_attributes is not null then
      v_group_attributes := null;
      foreach v_attribute in array v_attributes loop
        if v_attribute = any(in_object_attribute_codes) then
          v_group_attributes := v_group_attributes || array[v_attribute];
        end if;
      end loop;

      if v_group_attributes is not null then
        v_object_groups :=
          v_object_groups ||
          (
            jsonb_build_object('attributes', v_group_attributes) ||
            case when v_group ? 'name' then
              jsonb_build_object('name', json.get_string(v_group, 'name'))
            else
              jsonb '{}'
            end);
      end if;
    end if;
  end loop;

  return jsonb_build_object('groups', v_object_groups);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
