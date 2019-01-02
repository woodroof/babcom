-- drop function data.filter_template(jsonb, jsonb);

create or replace function data.filter_template(in_template jsonb, in_attributes jsonb)
returns jsonb
immutable
as
$$
declare
  v_groups jsonb := json.get_array(json.get_object(in_template), 'groups');
  v_group jsonb;
  v_attribute jsonb;
  v_attribute_name text;
  v_actions jsonb;
  v_name text;
  v_filtered_group jsonb;
  v_filtered_groups jsonb[];
  v_filtered_attributes text[];
begin
  assert json.get_object(in_attributes) is not null;

  for v_group in
    select *
    from jsonb_array_elements(v_groups)
  loop
    v_filtered_attributes := null;

    if v_group.value ? 'attributes' then
      for v_attribute in
        select *
        from jsonb_array_elements(json.get_array(v_group.value, 'attributes'))
      loop
        v_attribute_name := json.get_string(v_attribute.value);
        if in_attributes ? v_attribute_name then
          v_filtered_attributes := array_append(v_filtered_attributes, v_attribute_name);
        end if;
      end loop;
    end if;

    v_actions := json.get_array_opt(v_group.value, 'actions', null);

    if v_actions is not null or v_filtered_attributes is not null then
      v_name = json.get_string_opt(v_group.value, 'name', null);

      v_filtered_group := jsonb '{}';
      if v_name is not null then
        v_filtered_group := v_filtered_group || jsonb_create_object('name', v_name);
      end if;
      if v_filtered_attributes is not null then
        v_filtered_group := v_filtered_group || jsonb_create_object('attributes', jsonb_build_array(v_filtered_attributes));
      end if;
      if v_actions is not null then
        v_filtered_group := v_filtered_group || jsonb_create_object('actions', v_actions);
      end if;

      v_filtered_groups := array_append(v_filtered_groups, v_filtered_group);
    end if;
  end loop;

  return jsonb_create_object('groups', jsonb_build_array(v_filtered_groups));
end;
$$
language 'plpgsql';
